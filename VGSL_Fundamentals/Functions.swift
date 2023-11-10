// Copyright 2018 Yandex LLC. All rights reserved.

import Foundation

@inlinable
public func assertedCast<T, U>(_ value: T) -> U? {
  assert(value is U)
  return value as? U
}

@inlinable
public func assertedCast<T, U>(_ value: T?) -> U? {
  assert(value == nil || value is U)
  return value as? U
}

@inlinable
public func assertedCast<T, U>(_ value: T?, fallback: U) -> U {
  assertedCast(value) ?? fallback
}

@inlinable
public func identity<T>(_ value: T) -> T {
  value
}

@inlinable
public func traceId(_ x: AnyObject) -> UInt64 {
  UInt64(UInt(bitPattern: Unmanaged.passUnretained(x).toOpaque()))
}

@inlinable
public func autoReset<T, U>(
  _ value: inout T, _ newValue: T, _ code: () throws -> U
) rethrows -> U {
  let oldValue = value
  value = newValue
  defer {
    value = oldValue
  }
  return try code()
}

public func asyncActionAssertCompletionOnMT(
  _ action: @escaping AsyncAction
) -> AsyncAction {
  { completion in
    action {
      assert(Thread.isMainThread)
      completion()
    }
  }
}

@inlinable
public func partialApply<T, U>(_ f: @escaping (T) -> U, with arg: T) -> () -> U {
  { f(arg) }
}
