// Copyright 2021 Yandex LLC. All rights reserved.

import Foundation

private let __RWLockUsesAllocatedUnfairLock: AllocatedUnfairLock<Bool> = .init(initialState: false)
public var _RWLockUsesAllocatedUnfairLock: Bool {
  get {
    __RWLockUsesAllocatedUnfairLock.withLock { $0 }
  }
  set {
    __RWLockUsesAllocatedUnfairLock.withLock { $0 = newValue }
  }
}

public struct RWLock {
  private let impl: any _ReadWriteLock

  public init() {
    self.impl = _RWLockUsesAllocatedUnfairLock
      ? _AllocatedUnfairLockReadWriteLockAdapter()
      : _RWLockDeprecated()
  }

  public func read<T>(_ block: () throws -> T) rethrows -> T {
    try impl.read(block)
  }

  public func write<T>(_ block: () throws -> T) rethrows -> T {
    try impl.write(block)
  }
}

private protocol _ReadWriteLock {
  func read<T>(_ block: () throws -> T) rethrows -> T
  func write<T>(_ block: () throws -> T) rethrows -> T
}

private struct _AllocatedUnfairLockReadWriteLockAdapter: _ReadWriteLock {
  var underlying: AllocatedUnfairLock<Void>

  init(underlying: AllocatedUnfairLock<Void>) {
    self.underlying = underlying
  }

  init() {
    self.init(underlying: AllocatedUnfairLock())
  }

  func read<T>(_ block: () throws -> T) rethrows -> T {
    try underlying.withLockUnchecked(block)
  }

  func write<T>(_ block: () throws -> T) rethrows -> T {
    try underlying.withLockUnchecked(block)
  }
}

private final class _RWLockDeprecated: _ReadWriteLock {
  var lock = pthread_rwlock_t()

  init() {
    pthread_rwlock_init(&lock, nil)
  }

  deinit {
    pthread_rwlock_destroy(&lock)
  }

  func read<T>(_ block: () throws -> T) rethrows -> T {
    pthread_rwlock_rdlock(&lock)
    defer { pthread_rwlock_unlock(&lock) }
    return try block()
  }

  func write<T>(_ block: () throws -> T) rethrows -> T {
    pthread_rwlock_wrlock(&lock)
    defer { pthread_rwlock_unlock(&lock) }
    return try block()
  }
}
