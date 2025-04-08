// Copyright 2015 Yandex LLC. All rights reserved.

import Foundation

public typealias MainThreadRunner = @Sendable (@escaping @MainActor () -> Void) -> Void
public typealias MainThreadAsyncRunner = @Sendable (@escaping @MainActor () -> Void) -> Void
public typealias BackgroundRunner = (@escaping @Sendable () -> Void) -> Void
public typealias SyncQueueRunner = (@escaping @Sendable () -> Void) -> Void
public typealias DelayedExecution = (TimeInterval, @escaping () -> Void) -> Void
public typealias DelayedRunner = (_ delay: TimeInterval, _ block: @escaping @Sendable () -> Void)
  -> Cancellable

@_unavailableFromAsync(message: "await the call to the @MainActor closure directly")
@available(iOS, introduced: 9.0, deprecated: 13.0, message: "Use MainActor.assumeIsolated instead.")
private func backportedAssumeIsolatedToMainActor<T>(
  _ operation: @MainActor () throws -> T,
  file _: StaticString = #fileID, line _: UInt = #line
) rethrows -> T where T: Sendable {
  typealias YesActor = @MainActor () throws -> T
  typealias NoActor = () throws -> T

  assert(Thread.isMainThread)
  // To do the unsafe cast, we have to pretend it's @escaping.
  return try withoutActuallyEscaping(operation) {
    (_ fn: @escaping YesActor) throws -> T in
    let rawFn = unsafeBitCast(fn, to: NoActor.self)
    return try rawFn()
  }
}

@_unavailableFromAsync(message: "await the call to the @MainActor closure directly")
public func assumeIsolatedToMainActor<T>(
  _ operation: @MainActor () throws -> T,
  file _: StaticString = #fileID, line _: UInt = #line
) rethrows -> T where T: Sendable {
  if #available(iOS 13.0, tvOS 13.0, macOS 10.15, *) {
    try MainActor.assumeIsolated {
      try operation()
    }
  } else {
    try backportedAssumeIsolatedToMainActor {
      try operation()
    }
  }
}

@Sendable
public func onMainThread(_ block: @escaping @MainActor () -> Void) {
  if Thread.isMainThread {
    assumeIsolatedToMainActor {
      block()
    }
  } else {
    DispatchQueue.main.async(execute: block)
  }
}

public func onMainThreadResult<T: Sendable>(
  _ function: @escaping @MainActor () -> T
) -> Future<T> {
  let (future, feed) = Future<T>.create()
  onMainThread {
    feed(function())
  }
  return future
}

public func onMainThreadResult<T: Sendable>(_ function: @escaping @Sendable () -> Future<T>)
  -> Future<T> {
  let (future, feed) = Future<T>.create()
  onMainThread {
    function().resolved { result in
      onMainThread {
        feed(result)
      }
    }
  }
  return future
}

/// Executes a @MainActor closure by bypassing actor isolation checks.
///
/// - Warning: Only use if you fully understand the memory safety implications.
@_unavailableFromAsync
@inlinable
@inline(__always)
@_spi(Unsafe)
public func runUnsafelyOnMainActor<T>(_ body: @MainActor () throws -> T) rethrows -> T {
  try withoutActuallyEscaping(body) { fn in
    try unsafeBitCast(fn, to: (() throws -> T).self)()
  }
}

@Sendable
@inlinable
public func onMainThreadAsync(_ block: @escaping @MainActor () -> Void) {
  DispatchQueue.main.async(execute: block)
}

@inlinable
@Sendable
public func onMainThreadSync<T: Sendable>(_ block: @MainActor () -> T) -> T {
  if Thread.isMainThread {
    return assumeIsolatedToMainActor {
      block()
    }
  } else {
    return DispatchQueue.main.sync {
      assumeIsolatedToMainActor {
        block()
      }
    }
  }
}

@inlinable
public func onBackgroundThread(_ block: @escaping @Sendable () -> Void) {
  onBackgroundThread(qos: .default)(block)
}

public func onBackgroundThread(
  qos: DispatchQoS.QoSClass
) -> (@escaping @Sendable () -> Void) -> Void {
  {
    DispatchQueue.global(qos: qos).async(execute: $0)
  }
}

public func invokeImmediately(_ block: @escaping () -> Void) {
  block()
}

@discardableResult
public func dispatchAfter(
  _ delay: TimeInterval,
  block: @escaping MainActorAction
) -> Cancellable {
  after(delay, onQueue: .main) {
    assumeIsolatedToMainActor {
      block()
    }
  }
}

public func after(_ delay: TimeInterval, block: @escaping () -> Void) {
  _ = after(delay, onQueue: .main, block: block)
}

@discardableResult
public func after(
  _ delay: TimeInterval,
  onQueue queue: DispatchQueue,
  block: @escaping () -> Void
) -> Cancellable {
  let fireTime = DispatchTime.now() + delay
  nonisolated(unsafe) let workItem = DispatchWorkItem(block: block)
  queue.asyncAfter(deadline: fireTime, execute: workItem)
  return CallbackCancellable {
    workItem.cancel()
  }
}

@inlinable
public func performAsyncAction<T>(
  _ action: (@escaping (T) -> Void) -> Void,
  withMinimumDelay minimumDelay: TimeInterval,
  skipDelayPredicate: @escaping (T) -> Bool,
  completion: @escaping (T) -> Void,
  delayedExecutor: DelayedExecution
) {
  var minimumDelayPassed = false
  var value: T?
  var completion: ((T) -> Void)? = completion

  func tryComplete() {
    if let value, minimumDelayPassed || skipDelayPredicate(value) {
      completion?(value)
      completion = nil
    }
  }

  delayedExecutor(minimumDelay) {
    minimumDelayPassed = true
    tryComplete()
  }

  action {
    value = $0
    tryComplete()
  }
}
