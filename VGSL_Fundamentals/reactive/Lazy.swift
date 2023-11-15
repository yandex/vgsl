// Copyright 2018 Yandex LLC. All rights reserved.

import Foundation

#if DEBUG && canImport(OSLog)
@_implementationOnly import OSLog
#endif

@dynamicMemberLookup
public final class Lazy<T> {
  @usableFromInline
  internal typealias Preload = () -> Void
  public typealias Getter = () -> T

  @usableFromInline
  internal enum State {
    case created(Preload, Getter, Promise<T>)
    case loading(Future<T>)
    case loaded(T)
  }

  @usableFromInline
  internal var state: State

  #if DEBUG
  @usableFromInline
  internal var _wasRead = false
  #endif

  @inlinable
  internal init(state: State) {
    self.state = state
  }

  @inlinable
  deinit {
    traceDeinit()
  }

  @inlinable
  public convenience init(getter: @escaping Getter) {
    self.init(preload: {}, getter: getter)
  }

  @inlinable
  public convenience init(onMainThreadGetter getter: @escaping Getter) {
    func onMainThreadGetter() -> T {
      assert(Thread.isMainThread)
      return getter()
    }
    self.init(getter: onMainThreadGetter)
  }

  @inlinable
  public convenience init(preload: @escaping () -> Void, getter: @escaping () -> T) {
    self.init(state: .created(preload, getter, Promise()))
  }

  /// Produces a Lazy in not loaded state with a given value.
  ///
  /// Even thou the value is already on hands the resulting Lazy will
  /// behave like it was created with a getter, and `currentValue`
  /// will be `nil` until the Lazy is read.
  /// Use `init(loaded:)` when you need a Lazy in loaded state.
  @inlinable
  public convenience init(value: T) {
    self.init(getter: { value })
  }

  /// Produces a Lazy in loaded state with a given value.
  ///
  /// The resulting Lazy will immediately have a non-nil `currentValue`.
  @inlinable
  public convenience init(loaded value: T) {
    self.init(state: .loaded(value))
  }

  @inlinable
  public var value: T {
    #if DEBUG
    _wasRead = true
    #endif
    return getValue(eagerEvaluation: false, expectLoaded: false)
  }

  @inlinable
  public var currentValue: T? {
    switch state {
    case .created, .loading:
      return nil
    case let .loaded(value):
      return value
    }
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
      // If the Lazy is already loaded we don't need to keep a reference to it
      return Future(payload: value)
    }
  }

  @inlinable
  internal func getValue(eagerEvaluation: Bool, expectLoaded: Bool) -> T {
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
        fatalError("Attempt to load Lazy while in loading state")

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
  /// Resulting Lazy will be **loaded right after the current one loads**.
  /// Resulting Lazy will also contain a copy of the result of transformation.
  /// `transform` will be invoked once.
  /// `future` of the resulting Lazy will be resolved once the parent future is resolved.
  /// Use this function only if you intend to load the value **eagerly**.
  /// Otherwise consider other types of transformation,
  /// i.e. `Lazy(getter: { someTranformation(anotherLazy.value) })`
  /// or `lazyMap { someTranformation($0) }`.
  public func map<U>(_ transform: @escaping (T) -> U) -> Lazy<U> {
    traceMap(toType: U.self)
    func preload() {
      self.ensureIsLoaded()
    }
    func transformingGetter() -> U {
      transform(self.getValue(eagerEvaluation: false, expectLoaded: true))
    }
    let result = Lazy<U>(preload: preload, getter: transformingGetter)
    weak var weakResult: Lazy<U>? = result
    func onResolved(_: T) {
      _ = weakResult?.getValue(eagerEvaluation: true, expectLoaded: false)
    }
    future.resolved(onResolved)
    return result
  }

  @inlinable
  public func lazyMap<U>(_ transform: @escaping (T) -> U) -> Lazy<U> {
    traceMap(toType: U.self)
    func preload() {
      self.ensureIsLoaded()
    }
    func transformingGetter() -> U {
      transform(self.getValue(eagerEvaluation: false, expectLoaded: true))
    }
    let result = Lazy<U>(preload: preload, getter: transformingGetter)
    return result
  }

  @inlinable
  public subscript<U>(dynamicMember path: KeyPath<T, U>) -> Lazy<U> {
    func dynamicMemberGetter(_ object: T) -> U {
      object[keyPath: path]
    }
    return map(dynamicMemberGetter)
  }
}

extension Lazy {
  @inlinable
  internal func traceWillLoad(eagerEvaluation: Bool) {
    #if DEBUG
    if _LazyTraceLoggingEnabled {
      logDebug("Lazy: Will load. eager=\(eagerEvaluation) T=<\(T.self)>")
    }
    if eagerEvaluation {
      _traceWillLoadEager()
    } else {
      _traceWillLoadNotEager()
    }
    #endif
  }

  @inlinable
  internal func traceMap<U>(toType: U.Type) {
    #if DEBUG
    let isLoaded = future.isFulfilled
    if _LazyTraceLoggingEnabled {
      logDebug("Lazy: Create map. isLoaded=\(isLoaded) T=<\(T.self)> U=<\(toType)>")
    }
    if isLoaded {
      _traceMapFromLoaded()
    }
    #endif
  }

  @inlinable
  internal func traceDeinit() {
    #if DEBUG
    let isLoaded = future.isFulfilled
    if _LazyTraceLoggingEnabled {
      logDebug("Lazy: Deinit. isLoaded=\(isLoaded) wasRead=\(_wasRead) T=<\(T.self)>")
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
  internal func logDebug(_ string: String) {
    #if canImport(OSLog)
    if #available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *) {
      Logger(subsystem: "Lazy", category: "Trace").debug("\(string)")
    }
    #endif
  }

  @inlinable
  internal func _traceWillLoadEager() {}

  @inlinable
  internal func _traceWillLoadNotEager() {}

  @inlinable
  internal func _traceMapFromLoaded() {}

  @inlinable
  internal func _traceDeinitNotLoaded() {}

  @inlinable
  internal func _traceDeinitNotRead() {}
  #endif
}

#if DEBUG
public var _LazyTraceLoggingEnabled = false
#endif
