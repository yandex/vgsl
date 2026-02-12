// Copyright 2026 Yandex LLC. All rights reserved.

import Foundation

#if DEBUG && canImport(OSLog)
internal import OSLog
#endif

@propertyWrapper
@dynamicMemberLookup
public final class ResettableLazy<T> {
  @usableFromInline
  typealias Preload = () -> Void
  public typealias Getter = () -> T

  @usableFromInline
  enum State {
    case created(Preload, Getter, Promise<T>)
    case loading(Future<T>)
    case loaded(T)
  }

  @usableFromInline
  var state: State

  // Store the original preload and getter for reset functionality
  @usableFromInline
  let originalPreload: Preload
  @usableFromInline
  let originalGetter: Getter

  #if DEBUG
  @usableFromInline
  var _wasRead = false
  #endif

  @inlinable
  init(state: State, preload: @escaping Preload, getter: @escaping Getter) {
    self.state = state
    self.originalPreload = preload
    self.originalGetter = getter
  }

  @inlinable
  deinit {
    traceDeinit()
  }

  @inlinable
  public convenience init(getter: @escaping Getter) {
    let preload = {}
    self.init(state: .created(preload, getter, Promise()), preload: preload, getter: getter)
  }

  @inlinable
  public convenience init(onMainThreadGetter getter: @escaping Getter) {
    func onMainThreadGetter() -> T {
      assert(Thread.isMainThread)
      return getter()
    }
    let preload = {}
    self.init(
      state: .created(preload, onMainThreadGetter, Promise()),
      preload: preload,
      getter: onMainThreadGetter
    )
  }

  @inlinable
  public convenience init(preload: @escaping () -> Void, getter: @escaping () -> T) {
    self.init(state: .created(preload, getter, Promise()), preload: preload, getter: getter)
  }

  /// Produces a ResettableLazy in not loaded state with a given value.
  ///
  /// Even thou the value is already on hands the resulting ResettableLazy will
  /// behave like it was created with a getter, and `currentValue`
  /// will be `nil` until the ResettableLazy is read.
  /// Use `init(loaded:)` when you need a ResettableLazy in loaded state.
  @inlinable
  public convenience init(value: T) {
    let getter = { value }
    let preload = {}
    self.init(state: .created(preload, getter, Promise()), preload: preload, getter: getter)
  }

  /// Produces a ResettableLazy in loaded state with a given value.
  ///
  /// The resulting ResettableLazy will immediately have a non-nil `currentValue`.
  @inlinable
  public convenience init(loaded value: T) {
    let getter = { value }
    let preload = {}
    self.init(state: .loaded(value), preload: preload, getter: getter)
  }

  @inlinable
  public var value: T {
    #if DEBUG
    _wasRead = true
    #endif
    return getValue(eagerEvaluation: false, expectLoaded: false)
  }

  @inlinable
  public var wrappedValue: T {
    value
  }

  @inlinable
  public var currentValue: T? {
    switch state {
    case .created, .loading:
      nil
    case let .loaded(value):
      value
    }
  }

  /// Resets the lazy value to its initial state
  public func reset() {
    state = .created(originalPreload, originalGetter, Promise())
    #if DEBUG
    _wasRead = false
    #endif
  }

  @inlinable
  public var future: Future<T> {
    func doNothingRetainSelf(_: T) {
      // Capture self until self is loaded.
      // Ownership graph will look as follows:
      // self -> stored future -> interface future
      // interface future -> self
      // We expect this closure (and its captured `self`) to be released once
      // the stored future is resolved.
      // See `test_NonStoredLazyIsRetainedByFuture` for details.
      withExtendedLifetime(self) {}
    }

    func makeFutureWithAssociatedSelf(parent: Future<T>) -> Future<T> {
      let result = parent.map(identity(_:))
      result.resolved(doNothingRetainSelf(_:)) // associate self with the result
      return result
    }

    switch state {
    case let .created(_, _, promise):
      let storedFuture = promise.future
      return makeFutureWithAssociatedSelf(parent: storedFuture)

    case let .loading(storedFuture):
      return makeFutureWithAssociatedSelf(parent: storedFuture)

    case let .loaded(value):
      // If the ResettableLazy is already loaded we don't need to keep a reference to it
      return Future(payload: value)
    }
  }

  @inlinable
  func getValue(eagerEvaluation: Bool, expectLoaded: Bool) -> T {
    while true {
      switch state {
      case let .created(preload, getter, _):
        assert(!expectLoaded, "Value is expected to be loaded")
        preload()

        guard case let .created(_, _, promise) = state else {
          // During invocation of `preload` we could enter the `getValue` again
          // and change the state. In this case by the time we return to this frame
          // the state is probably `loaded` already, so we reevaluate the switch.
          continue
        }
        state = .loading(promise.future)

        traceWillLoad(eagerEvaluation: eagerEvaluation)
        let value = getter()

        if case .loading = state {
        } else {
          assertionFailure()
        }
        state = .loaded(value)
        promise.resolve(value)

      case .loading:
        fatalError("Attempt to load ResettableLazy while in loading state")

      case let .loaded(value):
        return value
      }
    }
  }

  @inlinable
  public func whenLoaded(perform body: @escaping Future<T>.Callback) {
    future.resolved(body)
  }

  @inlinable
  public func ensureIsLoaded() {
    switch state {
    case .created:
      _ = getValue(eagerEvaluation: false, expectLoaded: false)
    case .loading, .loaded:
      break
    }
  }

  /// Transforms this lazy into a new one **eagerly**.
  ///
  /// Resulting ResettableLazy will be **loaded right after the current one loads**.
  /// Resulting ResettableLazy will also contain a copy of the result of transformation.
  /// `transform` will be invoked once.
  /// `future` of the resulting ResettableLazy will be resolved once the parent future is resolved.
  /// Use this function only if you intend to load the value **eagerly**.
  /// Otherwise consider other types of transformation,
  /// i.e. `ResettableLazy(getter: { someTransformation(anotherLazy.value) })`
  /// or `lazyMap { someTransformation($0) }`.
  public func map<U>(_ transform: @escaping (T) -> U) -> ResettableLazy<U> {
    traceMap(toType: U.self)
    func preload() {
      self.ensureIsLoaded()
    }
    func transformingGetter() -> U {
      transform(self.getValue(eagerEvaluation: false, expectLoaded: true))
    }
    let result = ResettableLazy<U>(preload: preload, getter: transformingGetter)
    #if swift(>=6.2)
    weak let weakResult: ResettableLazy<U>? = result
    #else
    weak var weakResult: ResettableLazy<U>? = result
    #endif
    func onResolved(_: T) {
      _ = weakResult?.getValue(eagerEvaluation: true, expectLoaded: false)
    }
    future.resolved(onResolved)
    return result
  }

  /// Same as `map`, but the transformation is performed lazily
  /// (resulting lazy is not loaded when the current one loads).
  @inlinable
  public func lazyMap<U>(_ transform: @escaping (T) -> U) -> ResettableLazy<U> {
    traceMap(toType: U.self)
    func preload() {
      self.ensureIsLoaded()
    }
    func transformingGetter() -> U {
      transform(self.getValue(eagerEvaluation: false, expectLoaded: true))
    }
    let result = ResettableLazy<U>(preload: preload, getter: transformingGetter)
    return result
  }

  @inlinable
  public subscript<U>(dynamicMember path: KeyPath<T, U>) -> ResettableLazy<U> {
    func dynamicMemberGetter(_ object: T) -> U {
      object[keyPath: path]
    }
    return map(dynamicMemberGetter)
  }
}

extension ResettableLazy {
  @inlinable
  func traceWillLoad(eagerEvaluation: Bool) {
    #if DEBUG
    if _ResettableLazyTraceLoggingEnabled {
      logDebug("ResettableLazy: Will load. eager=\(eagerEvaluation) T=<\(T.self)>")
    }
    if eagerEvaluation {
      _traceWillLoadEager()
    } else {
      _traceWillLoadNotEager()
    }
    #endif
  }

  @inlinable
  func traceMap(toType: (some Any).Type) {
    #if DEBUG
    let isLoaded = future.isFulfilled
    if _ResettableLazyTraceLoggingEnabled {
      logDebug("ResettableLazy: Create map. isLoaded=\(isLoaded) T=<\(T.self)> U=<\(toType)>")
    }
    if isLoaded {
      _traceMapFromLoaded()
    }
    #endif
  }

  @inlinable
  func traceDeinit() {
    #if DEBUG
    let isLoaded = future.isFulfilled
    if _ResettableLazyTraceLoggingEnabled {
      logDebug("ResettableLazy: Deinit. isLoaded=\(isLoaded) wasRead=\(_wasRead) T=<\(T.self)>")
    }
    if !isLoaded {
      _traceDeinitNotLoaded()
    }
    if !_wasRead {
      _traceDeinitNotRead()
    }
    #endif
  }

  #if DEBUG
  @usableFromInline
  func logDebug(_ string: String) {
    #if canImport(OSLog)
    if #available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *) {
      Logger(subsystem: "ResettableLazy", category: "Trace").debug("\(string)")
    }
    #endif
  }

  @inlinable
  func _traceWillLoadEager() {}

  @inlinable
  func _traceWillLoadNotEager() {}

  @inlinable
  func _traceMapFromLoaded() {}

  @inlinable
  func _traceDeinitNotLoaded() {}

  @inlinable
  func _traceDeinitNotRead() {}
  #endif
}

#if DEBUG
private let __ResettableLazyTraceLoggingEnabled: AllocatedUnfairLock<Bool> =
  .init(initialState: false)
public var _ResettableLazyTraceLoggingEnabled: Bool {
  get {
    __ResettableLazyTraceLoggingEnabled.withLock { $0 }
  }
  set {
    __ResettableLazyTraceLoggingEnabled.withLock { $0 = newValue }
  }
}
#endif
