// Copyright 2019 Yandex LLC. All rights reserved.

import Foundation

/// `Future<T>` represents an asynchronous operation that can produce *single* value of type `T`
/// at some point in the future.
/// It provides mechanisms to attach callbacks that will be executed once the value is available.
public final class Future<T> {
  /// The type of callback to be executed when the future is resolved with a value.
  public typealias Callback = (T) -> Void

  /// Represents the state of the future, which can either be pending with a list of callbacks to
  /// execute upon fulfillment, or already fulfilled with a value.
  private enum State {
    case pending([Callback])
    case fulfilled(T)

    /// Provides an initial state for a future, indicating that it's pending without any callbacks
    /// attached yet.
    static var initial: State {
      .pending([])
    }
  }

  /// Stores the state of the future, ensuring thread-safe access and modification.
  private let state: AllocatedUnfairLock<State>

  /// Initializes a `Future` that is already fulfilled with a given value.
  /// - Parameter payload: The value to fulfill the future with.
  public init(payload: T) {
    state = AllocatedUnfairLock(uncheckedState: .fulfilled(payload))
  }

  /// Private initializer for creating a future in its initial, pending state.
  private init() {
    state = AllocatedUnfairLock(uncheckedState: .initial)
  }

  /// Creates a new, pending `Future` along with a feed object to resolve future with a value.
  /// - Returns: A tuple containing the future and a feed object to resolve it with a value.
  static func create() -> (Future<T>, feed: FutureFeed<T>) {
    let future = Future<T>()
    return (future, .init { t in future.accept(t) })
  }

  /// Attaches a callback to be executed when the future is resolved.
  /// If the future is already fulfilled, the callback is executed immediately.
  /// - Parameter callback: The closure to execute when the future is resolved.
  public func resolved(_ callback: @escaping Callback) {
    let immediateResult = state.withLockUnchecked { state -> T? in
      switch state {
      case let .pending(callbacks):
        state = .pending(callbacks + [callback])
        return nil
      case let .fulfilled(result):
        // DON'T pass control to the unknown code within the scope
        // It may lead to a recursive lock, which is unsupported
        return result
      }
    }
    if let immediateResult {
      callback(immediateResult)
    }
  }

  /// Attempts to unwrap the future's value if it's already fulfilled.
  /// - Returns: The future's value if available; otherwise, `nil`.
  public func unwrap() -> T? {
    state.withLockUnchecked { state in
      switch state {
      case .pending: return nil
      case let .fulfilled(result): return result
      }
    }
  }

  /// Resolves the future with a value and executes any pending callbacks.
  /// - Parameter result: The value to fulfill the future with.
  private func accept(_ result: T) {
    let callbacks = state.withLockUnchecked { state -> [Callback] in
      switch state {
      case let .pending(callbacks):
        state = .fulfilled(result)
        // DON'T pass control to the unknown code within the scope
        // It may lead to a recursive lock, which is unsupported
        return callbacks
      case let .fulfilled(currentResult):
        assertionFailure(
          "Future already has result: \(currentResult). Callstack: \(Thread.callStackSymbols.joined(separator: "\n"))"
        )
        return []
      }
    }
    for callback in callbacks {
      callback(result)
    }
  }
}

extension Future: Sendable where T: Sendable {
  /// Creates a new, pending sendable `Future` along with a feed object to resolve future with a
  /// value.
  /// - Returns: A tuple containing the future and a feed object to resolve it with a value.
  static func create() -> (Future<T>, feed: FutureFeed<T>) {
    let future = Future<T>()
    return (future, .init { t in future.accept(t) })
  }
}

extension Future: Cancellable where T: Cancellable {
  /// Cancels the task associated with the future. If the future's value (`T`) is a task that
  /// conforms to `Cancellable`, this method calls `cancel` on that task.
  public func cancel() {
    self.resolved { $0.cancel() }
  }
}

extension Future where T == Void {
  @inlinable
  public convenience init() {
    self.init(payload: ())
  }
}

extension Future: ExpressibleByBooleanLiteral where T == Bool {
  @inlinable
  public convenience init(booleanLiteral value: Bool) {
    self.init(payload: value)
  }
}

extension Future {
  /// Transforms the result of this future to a new future with a different type.
  ///
  /// - Parameter transform: A closure that takes the current future's payload and returns a new
  /// value.
  /// - Returns: A new `Future<U>` containing the transformed value.
  public func map<U>(_ transform: @escaping (T) -> U) -> Future<U> {
    let (future, feed) = Future<U>.create()
    resolved { payload in
      feed(transform(payload))
    }
    return future
  }

  /// Transforms the result of this future to a new future with a different type, where the
  /// transformation itself is asynchronous and returns another future.
  ///
  /// - Parameter transform: A closure that takes the current future's payload and returns a new
  /// `Future<U>`.
  /// - Returns: A new `Future<U>` resulting from the transformation.
  public func flatMap<U>(_ transform: @escaping (T) -> Future<U>) -> Future<U> {
    let (future, feed) = Future<U>.create()
    resolved { payload in
      let next = transform(payload)
      next.resolved(feed.feedFunction)
    }
    return future
  }

  /// Performs an action after this future is resolved, regardless of its value, and returns a new
  /// future containing the result of the action.
  ///
  /// - Parameter continuation: A closure that returns a new value.
  /// - Returns: A new `Future<U>` containing the result of the continuation action.
  @inlinable public func after<U>(_ continuation: @escaping () -> U) -> Future<U> {
    map { _ in continuation() }
  }

  /// Similar to `after`, but the continuation itself returns a future.
  ///
  /// - Parameter continuation: A closure that returns a new `Future<U>`.
  /// - Returns: A new `Future<U>` resulting from the continuation.
  @inlinable public func after<U>(_ continuation: @escaping () -> Future<U>) -> Future<U> {
    flatMap { _ in continuation() }
  }
}

extension Future {
  /// Transforms the future into one that resolves with a Void type, effectively ignoring or
  /// dropping the original payload.
  /// This is useful in scenarios where the completion of an asynchronous operation is important,
  /// but the result itself is not.
  ///
  /// - Returns: A new `Future<Void>` that resolves when the original future resolves, discarding
  /// its payload.
  @inlinable public func dropPayload() -> Future<Void> {
    after { () }
  }

  /// Forwards the result of the future to a given `Promise<T>`, resolving it with the future's
  /// payload.
  /// This is particularly useful for converting a `Future` into a `Promise`, or when you want to
  /// chain multiple asynchronous operations.
  ///
  /// - Parameter promise: The `Promise<T>` to be resolved with the future's result.
  @inlinable public func forward(to promise: Promise<T>) {
    resolved(promise.resolve)
  }
}

extension Future where T: Sendable {
  /// Forwards the result of the future to a given `Promise<T>` on a specific dispatch queue.
  /// This allows for thread-safe resolution of promises in environments where the execution context
  /// matters.
  ///
  /// - Parameters:
  ///   - promise: The `Promise<T>` to be resolved with the future's result.
  ///   - queue: The `DispatchQueue` on which to resolve the promise.
  @inlinable public func forward(to promise: Promise<T>, on queue: DispatchQueue) {
    resolved { payload in queue.async { promise.resolve(payload) } }
  }

  /// Creates a new future that resolves after a specified time interval, effectively delaying the
  /// resolution.
  ///
  /// - Parameters:
  ///   - timeInterval: The delay, in seconds, before the future resolves.
  ///   - queue: The dispatch queue on which to schedule the delay.
  /// - Returns: A new `Future` that will resolve with the original future's payload after the
  /// specified delay.
  public func after(timeInterval: Double, on queue: DispatchQueue) -> Future {
    let (future, feed) = Future<T>.create()
    func forward(_ result: T) {
      queue.asyncAfter(deadline: .now() + .milliseconds(Int(timeInterval * 1000))) {
        feed(result)
      }
    }
    resolved(forward)
    return future
  }

  /// Transfers the resolution of the future to a specified dispatch queue.
  ///
  /// - Parameter queue: The dispatch queue to which the future's resolution should be transferred.
  /// - Returns: A new `Future` that will resolve on the specified queue.
  public func transfer(to queue: DispatchQueue) -> Future<T> {
    let (future, feed) = Future<T>.create()
    resolved { payload in
      queue.async {
        feed(payload)
      }
    }
    return future
  }

  /// Creates a future that executes an asynchronous task on a specified background queue and
  /// resolves on another queue.
  ///
  /// - Parameters:
  ///   - task: The asynchronous task returning a future.
  ///   - executeQueue: The queue on which the task is executed.
  ///   - resolveQueue: The queue on which the future is resolved.
  /// - Returns: A `Future<T>` that will be resolved with the task's result.
  public static func fromAsyncBackgroundTask(
    _ task: @escaping @Sendable () -> Future<T>,
    executeOn executeQueue: DispatchQueue,
    resolveOn resolveQueue: DispatchQueue
  ) -> Future<T> {
    let (future, feed) = Future<T>.create()
    executeQueue.async {
      let taskComplete = task()
      taskComplete.resolved { payload in resolveQueue.async { feed(payload) } }
    }
    return future
  }

  /// Creates a future that executes a synchronous task on a specified background queue and resolves
  /// on another queue.
  ///
  /// - Parameters:
  ///   - task: The synchronous task to be executed.
  ///   - executeQueue: The queue on which the task will be executed.
  ///   - resolveQueue: The queue on which the future will be resolved.
  /// - Returns: A `Future<T>` that will be resolved with the task's result.
  public static func fromBackgroundTask(
    _ task: @escaping @Sendable () -> T,
    executingOn executeQueue: DispatchQueue,
    resolvingOn resolveQueue: DispatchQueue
  ) -> Future<T> {
    let (future, feed) = Future<T>.create()
    executeQueue.async {
      let result = task()
      resolveQueue.async {
        feed(result)
      }
    }
    return future
  }

  /// Creates a future that executes a synchronous task with an argument on a specified background
  /// queue and resolves the result on another queue.
  /// This method is useful for operations that require an input parameter and need to be executed
  /// asynchronously to prevent blocking the main thread.
  ///
  /// - Parameters:
  ///   - task: The synchronous task to be executed, which takes an argument of type `U`.
  ///   - argument: The argument to pass to the task.
  ///   - executeQueue: The queue on which the task will be executed.
  ///   - resolveQueue: The queue on which the future will be resolved.
  /// - Returns: A `Future<T>` that will be resolved with the task's result.
  public static func fromBackgroundTask<U: Sendable>(
    _ task: @escaping @Sendable (U) -> T,
    _ argument: U,
    executingOn executeQueue: DispatchQueue,
    resolvingOn resolveQueue: DispatchQueue
  ) -> Future<T> {
    let (future, feed) = Future<T>.create()
    executeQueue.async {
      let result = task(argument)
      resolveQueue.async {
        feed(result)
      }
    }
    return future
  }

  /// Creates a future that times out after a specified interval, providing a fallback value if the
  /// original future doesn't resolve in time.
  ///
  /// - Parameters:
  ///   - timeout: The timeout interval in seconds.
  ///   - queue: The dispatch queue to schedule the timeout on.
  ///   - value: The fallback value if the timeout occurs.
  /// - Returns: A `Future` that either resolves with the original future's result or the fallback
  /// value after the timeout.
  public func timingOut(
    after timeout: TimeInterval,
    on queue: DispatchQueue,
    withFallback value: T
  ) -> Future {
    let fallback = Future(payload: value).after(timeInterval: timeout, on: queue)
    return first(self, fallback).map(\.value)
  }
}

extension Future {
  /// Checks whether the future has been fulfilled.
  ///
  /// - Returns: `true` if the future has been resolved with a payload, `false` otherwise.
  public var isFulfilled: Bool {
    guard let _ = unwrap() else { return false }
    return true
  }
}

extension Future {
  /// Creates a `Future` that executes a non-future-returning asynchronous task after a specified
  /// time interval.
  ///
  /// This method is useful for deferring the execution of a task and wrapping its result in a
  /// `Future`.
  ///
  /// - Parameters:
  ///   - task: The task to execute, returning a value of type `T`.
  ///   - interval: The delay, in seconds, before the task is executed.
  ///   - queue: The dispatch queue on which the task will be executed.
  /// - Returns: A `Future<T>` representing the result of the asynchronous task.
  @inlinable public static func fromAsyncTask(
    _ task: @escaping () -> T,
    after interval: TimeInterval,
    on queue: DispatchQueue
  ) -> Future {
    Future<Void>().after(timeInterval: interval, on: queue).after(task)
  }

  /// Creates a `Future` that executes a future-returning asynchronous task after a specified time
  /// interval.
  ///
  /// This variant is designed for tasks that themselves return a `Future<T>`, allowing for easy
  /// chaining of asynchronous operations that are initiated after a delay.
  ///
  /// - Parameters:
  ///   - task: The task to execute, returning a `Future<T>`.
  ///   - interval: The delay, in seconds, before the task is executed.
  ///   - queue: The dispatch queue on which the task will be executed.
  /// - Returns: A `Future<T>` representing the result of the asynchronous task.
  @inlinable public static func fromAsyncTask(
    _ task: @escaping () -> Future<T>,
    after interval: TimeInterval,
    on queue: DispatchQueue
  ) -> Future {
    Future<Void>().after(timeInterval: interval, on: queue).after(task)
  }
}

extension Future {
  /// Creates a future from an asynchronous task.
  ///
  /// - Parameter task: The asynchronous task that accepts a completion handler.
  /// - Returns: A `Future` representing the result of the asynchronous task.
  public static func fromAsyncTask(_ task: (@escaping (T) -> Void) -> Void) -> Future {
    let (future, feed) = Future<T>.create()
    task(feed.feedFunction)
    return future
  }

  /// Wraps an asynchronous task into a future.
  ///
  /// - Parameter task: A closure representing an asynchronous task that accepts a completion
  /// handler.
  /// - Returns: A `Future<T>` that will be resolved with the task's result.
  public static func wrap(_ task: (@escaping (T) -> Void) -> Void) -> Future<T> {
    let (future, feed) = Future<T>.create()
    task { feed($0) }
    return future
  }

  /// Wraps an asynchronous task with parameters into a future.
  ///
  /// - Parameters:
  ///   - task: A closure representing an asynchronous task that takes parameters and a completion
  /// handler.
  ///   - p1: The first parameter for the task.
  ///   - p2: The second parameter for the task.
  /// - Returns: A `Future<T>` that will be resolved with the task's result.
  public static func wrap<T1, T2>(
    _ task: (T1, T2, @escaping (T) -> Void) -> Void,
    _ p1: T1,
    _ p2: T2
  ) -> Future<T> {
    let (future, feed) = Future<T>.create()
    task(p1, p2) { feed($0) }
    return future
  }

  /// Immediately creates a resolved future with a given payload.
  ///
  /// - Parameter payload: The value with which to resolve the future.
  /// - Returns: A `Future<T>` that is already resolved with the given payload.
  public static func resolved(_ payload: T) -> Future<T> {
    let (future, feed) = Future<T>.create()
    feed(payload)
    return future
  }
}

extension Either where T == U {
  /// A computed property that returns the value contained in the `Either` instance, regardless of
  /// whether it's in the `left` or `right` case. This property simplifies the usage of `Either`
  /// when both cases hold the same type, making it straightforward to access the underlying value.
  fileprivate var value: T {
    switch self {
    case let .left(value):
      return value
    case let .right(value):
      return value
    }
  }
}

extension Future where T == Void {
  public static func fromAsyncTask(_ task: (@escaping () -> Void) -> Void) -> Future {
    let (future, feed) = Future<Void>.create()
    task { feed(()) }
    return future
  }

  public static func after(_ barrier: Operation) -> Future {
    let promise = Promise<Void>()
    let operation = BlockOperation { promise.resolve() }
    operation.addDependency(barrier)
    // swiftlint:disable:next no_direct_use_for_main_queue
    OperationQueue.main.addOperation(operation)
    return promise.future
  }
}

public func all<T, U>(_ f1: Future<T>, _ f2: Future<U>) -> Future<(T, U)> {
  let (future, feed) = Future<(T, U)>.create()
  f1.resolved { p1 in
    f2.resolved { p2 in
      feed((p1, p2))
    }
  }
  return future
}

public func all<T, U, V>(
  _ f1: Future<T>,
  _ f2: Future<U>,
  _ f3: Future<V>
) -> Future<(T, U, V)> {
  let (future, feed) = Future<(T, U, V)>.create()
  f1.resolved { p1 in
    f2.resolved { p2 in
      f3.resolved { p3 in
        feed((p1, p2, p3))
      }
    }
  }
  return future
}

public func all<T1, T2, T3, T4>(
  _ f1: Future<T1>,
  _ f2: Future<T2>,
  _ f3: Future<T3>,
  _ f4: Future<T4>
) -> Future<(T1, T2, T3, T4)> {
  let (future, feed) = Future<(T1, T2, T3, T4)>.create()
  f1.resolved { p1 in
    f2.resolved { p2 in
      f3.resolved { p3 in
        f4.resolved { p4 in
          feed((p1, p2, p3, p4))
        }
      }
    }
  }
  return future
}

public func first<T, U>(_ a: Future<T>, _ b: Future<U>) -> Future<Either<T, U>> {
  let (future, feed) = Future<Either<T, U>>.create()
  var resolved = false
  func fullfil(_ value: Either<T, U>) {
    if !resolved {
      resolved = true
      feed(value)
    }
  }
  a.resolved {
    fullfil(.left($0))
  }
  b.resolved {
    fullfil(.right($0))
  }
  return future
}

@inlinable public func all<T>(futures: [Future<T>]) -> Future<[T]> {
  guard !futures.isEmpty else {
    return Future<[T]>(payload: [])
  }

  let finalPromise = Promise<[T]>()
  let result = AllocatedUnfairLock(
    uncheckedState: (
      values: [T?](repeating: nil, count: futures.count),
      fullfilledCount: 0
    )
  )
  for (index, future) in futures.enumerated() {
    future.resolved { value in
      result.withLock {
        $0.values[index] = value
        $0.fullfilledCount += 1
        if $0.fullfilledCount == futures.count {
          finalPromise.resolve($0.values.compactMap { $0 })
        }
      }
    }
  }
  return finalPromise.future
}

extension Future {
  /// Creates a `Signal` from the `Future`.
  ///
  /// The resulting `Signal` will deliver the value **exactly once**.
  /// If the future is already resolved for every subscription its observer
  /// will be invoked immediately.
  /// Once the future is resolved the observer will be released.
  /// Once the subscription is cancelled with `Disposable` the observer will be released.
  public func asSignal() -> Signal<T> {
    Signal(fromFuture: self)
  }

  public func asObservableVariable() -> ObservableVariable<T?> {
    func getter() -> T? {
      self.unwrap()
    }
    return ObservableVariable<T?>(
      getter: getter,
      newValues: Signal(_fromFulfillmentOfFuture: self).map(Optional.init(_:))
    )
  }

  public func asObservableVariable(fallbackUntilResolved: T) -> ObservableVariable<T> {
    func getter() -> T {
      self.unwrap() ?? fallbackUntilResolved
    }
    return ObservableVariable<T>(
      getter: getter,
      newValues: Signal(_fromFulfillmentOfFuture: self)
    )
  }
}

struct FutureFeed<T> {
  private nonisolated(unsafe) let feed: (T) -> Void

  init(_ feed: @escaping (T) -> Void) {
    self.feed = feed
  }

  func callAsFunction(_ item: T) {
    feed(item)
  }

  var feedFunction: (T) -> Void {
    feed
  }
}

extension FutureFeed: Sendable where T: Sendable {
  init(_ feed: @escaping @Sendable (T) -> Void) {
    self.feed = feed
  }

  var feedFunction: @Sendable (T) -> Void {
    { item in
      feed(item)
    }
  }
}
