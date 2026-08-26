// Copyright 2018 Yandex LLC. All rights reserved.

public final class Atomic<T>: Sendable {
  private let value: AllocatedUnfairLock<T>

  public init(initialValue: sending T) {
    value = AllocatedUnfairLock(sendingState: initialValue)
  }

  public func accessRead<U: Sendable>(
    _ block: (T) throws -> U
  ) rethrows -> U {
    try value.withLockUnchecked {
      try block($0)
    }
  }

  public func accessWrite<U: Sendable>(_ block: (inout T) throws -> U) rethrows -> U {
    try value.withLockUnchecked(block)
  }
}
