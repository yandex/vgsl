// Copyright 2020 Yandex LLC. All rights reserved.

public enum Combine {
  @inlinable
  public static func `throw`<T: Sendable>(_ first: T, last: T) throws -> T {
    throw CombineFailure(values: [first, last])
  }

  @inlinable
  public static func lastWithAssertionFailure<T: Sendable>(_ first: T, last: T) -> T {
    assertionFailure(CombineFailure(values: [first, last]).debugDescription)
    return last
  }
}

public struct CombineFailure<T: Sendable>: Error, CustomDebugStringConvertible {
  let values: [T]

  public init(values: [T]) {
    self.values = values
  }

  public var debugDescription: String {
    "Combine \(values) failed."
  }
}

extension CombineFailure: Equatable where T: Equatable {}
