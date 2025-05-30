// Copyright 2018 Yandex LLC. All rights reserved.

import Foundation

@dynamicMemberLookup
public struct Signal<T> {
  public let addObserver: (Observer<T>) -> Disposable

  @inlinable
  public func addObserver(_ action: @escaping (T) -> Void) -> Disposable {
    addObserver(Observer(action: action))
  }

  public init(addObserver: @escaping (Observer<T>) -> Disposable) {
    self.addObserver = addObserver
  }

  @inlinable
  public subscript<U>(dynamicMember path: KeyPath<T, U>) -> Signal<U> {
    map { $0[keyPath: path] }
  }

  @inlinable
  public subscript<ValueType, UnderlyingType>(
    dynamicMember path: KeyPath<UnderlyingType, ValueType>
  ) -> Signal<ValueType?> where T == UnderlyingType? {
    map { $0?[keyPath: path] }
  }

  @inlinable
  public subscript<ValueType, UnderlyingType>(
    dynamicMember path: KeyPath<UnderlyingType, ValueType?>
  ) -> Signal<ValueType?> where T == UnderlyingType? {
    map { $0?[keyPath: path] }
  }
}

extension Signal {
  public static var empty: Signal {
    Signal(addObserver: { _ in Disposable() })
  }

  @inlinable
  public static func value(_ value: T) -> Signal {
    Signal(addObserver: { observer in
      observer.action(value)
      return Disposable()
    })
  }

  /// Creates a `Signal` from `Future`.
  ///
  /// The resulting `Signal` will deliver the value **exactly once**.
  /// If the future is already resolved, for every subscription its observer
  /// will be invoked immediately.
  /// Once the future is resolved the observer will be released.
  /// Once the subscription is cancelled with `Disposable` the observer will be released.
  @inlinable
  public init(fromFuture future: Future<T>) {
    func onObserverSubscribed(observer: Observer<T>) -> Disposable {
      var observer = Optional(observer)
      func onResolved(value: T) {
        guard let action = observer?.action else {
          return
        }
        observer = nil
        action(value)
      }
      func onDispose() {
        observer = nil
      }
      future.resolved(onResolved(value:))
      return Disposable(onDispose)
    }
    self.init(addObserver: onObserverSubscribed(observer:))
  }

  /// Creates a `Signal` from `Future`.
  ///
  /// The resulting `Signal` will deliver the value **at most once**.
  /// If the future is already resolved by the time of subscription, no value
  /// will be delivered to its observer.
  /// Once the future is resolved the observer will be released.
  /// Once the subscription is cancelled with `Disposable` the observer will be released.
  @inlinable
  internal init(_fromFulfillmentOfFuture future: Future<T>) {
    func onObserverSubscribed(observer: Observer<T>) -> Disposable {
      guard !future.isFulfilled else {
        return .empty
      }
      return Self(fromFuture: future).addObserver(observer)
    }
    self.init(addObserver: onObserverSubscribed(observer:))
  }

  @inlinable
  public static func values(_ values: some Sequence<T> & Sendable) -> Signal {
    Signal(addObserver: { observer in
      for value in values {
        observer.action(value)
      }
      return Disposable()
    })
  }

  @inlinable
  public func startWith(_ valueProvider: @escaping () -> T) -> Signal {
    performingBeforeAddObserver { observer in
      let value = valueProvider()
      observer.action(value)
    }
  }

  @inlinable
  public func contramap<U>(_ transform: @escaping (Observer<U>) -> Observer<T>) -> Signal<U> {
    Signal<U>(addObserver: compose(addObserver, after: transform))
  }

  @inlinable
  public func map<U>(_ transform: @escaping (T) -> U) -> Signal<U> {
    contramap { $0.contramap(transform) }
  }

  @inlinable
  public func filter(_ predicate: @escaping (T) -> Bool) -> Signal {
    contramap { $0.filter(predicate) }
  }

  @inlinable
  public func compactMap<U>(_ transform: @escaping (T) -> U?) -> Signal<U> {
    contramap { $0.compactContramap(transform) }
  }

  @inlinable
  public func flatMap<U>(_ transform: @escaping (T) -> Signal<U>) -> Signal<U> {
    Signal<U>(addObserver: { uObserver in
      var innerDisposable: Disposable?
      let outerDisposable = self.addObserver { t in
        innerDisposable?.dispose()
        innerDisposable = transform(t).addObserver(uObserver)
      }
      return Disposable {
        outerDisposable.dispose()
        innerDisposable?.dispose()
      }
    })
  }

  @inlinable
  public func flatten<U>() -> Signal<U> where T == Signal<U> {
    flatMap(identity(_:))
  }

  public func takeFirst(_ count: Int = 1) -> Signal {
    guard count > 0 else {
      return .empty
    }
    return Signal(addObserver: { observer in
      var remaining = count
      weak var weakDisposable: Disposable?
      let disposable = self.addObserver { t in
        if remaining > 0 {
          observer.action(t)
          remaining -= 1
        }
        if remaining == 0 {
          weakDisposable?.dispose()
        }
      }
      if remaining == 0 {
        disposable.dispose()
      } else {
        weakDisposable = disposable
      }
      return disposable
    })
  }

  public func dropFirst(_ count: Int = 1) -> Signal {
    guard count > 0 else { return self }
    var skipCount = count + 1
    return filter { _ in
      if skipCount > 0 {
        skipCount -= 1
      }
      return skipCount == 0
    }
  }

  @inlinable
  public func performingBeforeAddObserver(_ sideEffect: @escaping (Observer<T>) -> Void) -> Signal {
    Signal(addObserver: { observer in
      sideEffect(observer)
      return self.addObserver(observer)
    })
  }

  @inlinable
  public func performingBeforeEachValue(_ sideEffect: @escaping (T) -> Void) -> Signal {
    contramap { $0.performingBeforeEachValue(sideEffect) }
  }

  @inlinable
  public func skipRepeats(
    areEqual: @escaping (T, T) -> Bool,
    initialValue: (() -> T?)? = nil
  ) -> Signal {
    contramap { $0.skipRepeats(areEqual: areEqual, initialValue: initialValue?()) }
  }

  @inlinable
  public func skipUntil(_ predicate: @escaping (T) -> Bool) -> Signal<T> {
    contramap { $0.skipUntil(predicate) }
  }

  @inlinable
  public func takeUntil(_ predicate: @escaping (T) -> Bool) -> Signal<T> {
    contramap { $0.takeUntil(predicate) }
  }

  @inlinable
  public func delay(_ interval: TimeInterval) -> Signal {
    Signal { observer in
      let cancellable: AllocatedUnfairLock<Cancellable?> = .init(initialState: nil)
      let disposable = addObserver { t in
        cancellable.withLock { $0 = after(interval, onQueue: .main) { observer.action(t) } }
      }
      return Disposable {
        disposable.dispose()
        cancellable.withLock { $0 }?.cancel()
      }
    }
  }

  @inlinable
  public func scan<U>(
    _ accumulator: U,
    updateAccumulator: @escaping (inout U, T) -> Void
  ) -> Signal<U> {
    var acc = accumulator
    return contramap { $0.contramap { (next: T) -> U in
      updateAccumulator(&acc, next)
      return acc
    }}
  }

  @inlinable
  public func scan<U>(
    _ accumulator: U,
    nextPartialResult: @escaping (U, T) -> U
  ) -> Signal<U> {
    scan(accumulator) { acc, next in
      acc = nextPartialResult(acc, next)
    }
  }
}

extension Signal where T: Sendable {
  @inlinable
  public func mapOnBackground<U>(
    _ transform: @Sendable @escaping (T) -> U,
    backgroundRunner: @escaping BackgroundRunner = onBackgroundThread,
    mainThreadAsyncRunner: @escaping MainThreadAsyncRunner = onMainThreadAsync
  ) -> Signal<U> {
    self.flatMap { it in
      Signal<U> { observer -> Disposable in
        Thread.assertIsMain()
        nonisolated(unsafe) let observer = observer
        var disposed = false
        backgroundRunner {
          let value = transform(it)
          mainThreadAsyncRunner {
            Thread.assertIsMain()
            guard !disposed else { return }
            observer.action(value)
          }
        }
        return Disposable { disposed = true }
      }
    }
  }
}

extension Signal {
  public static func fromAsync(_ asyncResultAction: @escaping AsyncResultAction<T>) -> Signal<T> {
    Signal<T>.init { (observer: Observer<T>) -> Disposable in
      var disposed = false
      let disposable = Disposable {
        disposed = true
      }
      asyncResultAction { result in
        guard !disposed else { return }
        observer.action(result)
      }
      return disposable
    }
  }
}

extension Signal where T == Void {
  public func addObserver(_ observer: @escaping Action) -> Disposable {
    addObserver { _ in observer() }
  }
}

extension Signal where T: Equatable {
  @inlinable
  public func skipRepeats(initialValue: (() -> T?)? = nil) -> Signal {
    skipRepeats(areEqual: ==, initialValue: initialValue)
  }
}

extension Signal {
  /// Makes a new Signal based on `self`. It, and all subscriptions (`Disposable`s)
  /// are made by it retain the `object`
  @inlinable
  public func retaining(object: some Any) -> Signal<T> {
    Signal(addObserver: { observer in
      let baseDisposable = addObserver(observer)
      return Disposable {
        withExtendedLifetime(object) {
          baseDisposable.dispose()
        }
      }
    })
  }
}

extension Signal {
  public static func merge(_ signals: Signal...) -> Signal {
    merge(signals)
  }

  public static func merge(_ signals: [Signal]) -> Signal {
    Signal(addObserver: { observer in
      var disposables = [Disposable]()
      for signal in signals {
        disposables.append(signal.addObserver(observer.action))
      }
      return Disposable(disposables)
    })
  }
}

extension Signal {
  public func assertingMainThread() -> Signal {
    performingBeforeAddObserver { _ in Thread.assertIsMain() }
      .performingBeforeEachValue { _ in Thread.assertIsMain() }
  }

  @inlinable
  public static func changesForKeyPath<Root: NSObject, Value>(
    _ keyPath: KeyPath<Root, Value>,
    onNSObject object: Root,
    options: NSKeyValueObservingOptions
  ) -> Signal where T == (object: Root, change: NSKeyValueObservedChange<Value>) {
    let signal = unsafeChangesForKeyPath(keyPath, onNSObject: object, options: options)
    return Signal(addObserver: { [weak weakObject = object] in
      let token = signal.addObserver($0)
      return Disposable { [object = weakObject] in
        withExtendedLifetime(object) {
          token.dispose()
        }
      }
    })
  }

  @inlinable
  public static func unsafeChangesForKeyPath<Root: NSObject, Value>(
    _ keyPath: KeyPath<Root, Value>,
    onNSObject object: Root,
    options: NSKeyValueObservingOptions
  ) -> Signal where T == (object: Root, change: NSKeyValueObservedChange<Value>) {
    return Signal(addObserver: { observer in
      nonisolated(unsafe) let observer = observer
      let token = object.observe(keyPath, options: options, changeHandler: { object, change in
        observer.action((object, change))
      })
      return Disposable {
        token.invalidate()
      }
    })
  }
}

extension Signal {
  @inlinable
  public func transmit<O>(to keyPath: ReferenceWritableKeyPath<O, T>, of object: O) -> Disposable {
    addObserver { object[keyPath: keyPath] = $0 }
  }

  @inlinable
  public func transmit<O>(
    to keyPath: ReferenceWritableKeyPath<O, T?>,
    of object: O
  ) -> Disposable {
    addObserver { object[keyPath: keyPath] = $0 }
  }

  @inlinable
  public func transmit<O: AnyObject>(
    to keyPath: ReferenceWritableKeyPath<O, T>,
    ofWeak object: O
  ) -> Disposable {
    addObserver { [weak object] in object?[keyPath: keyPath] = $0 }
  }
}

extension Lazy {
  @inlinable
  public func addObserver<U>(_ observer: Observer<U>) -> Disposable where T == Signal<U> {
    var token: Disposable?
    var observerToAdd: Observer<U>? = observer
    whenLoaded { signal in
      token = observerToAdd.map { signal.addObserver($0) }
    }
    return Disposable {
      withExtendedLifetime(self) {
        token?.dispose()
        observerToAdd = nil
      }
    }
  }
}

extension Signal {
  @inlinable
  public func dropPayload() -> Signal<Void> {
    map { _ in () }
  }
}

extension Signal {
  @inlinable
  public func firstAsFuture(shouldAssertOnMainThread: Bool = false) -> Future<T> {
    let promise = Promise<T>(shouldAssertOnMainThread: shouldAssertOnMainThread)
    let subscription = takeFirst().addObserver(promise.resolve)
    promise.future.resolved { _ in
      withExtendedLifetime(subscription) {}
    }
    return promise.future
  }
}
