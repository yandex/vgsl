// Copyright 2022 Yandex LLC. All rights reserved.

import os

public struct AllocatedUnfairLock<State>: @unchecked Sendable {
  public enum Ownership: Hashable, Sendable {
    case owner, notOwner
  }

  @usableFromInline
  typealias Buffer = ManagedBuffer<State, LowLevelLock>

  @usableFromInline
  let buffer: Buffer

  @inlinable
  public init(uncheckedState initialState: State) {
    buffer = Buffer.create(minimumCapacity: 1) { buffer in
      buffer.withUnsafeMutablePointerToElements { lock in
        ll_lock_init(lock)
      }
      return initialState
    }
  }

  @inlinable
  public init(sendingState: sending State) {
    self.init(uncheckedState: sendingState)
  }

  @inlinable
  public borrowing func withLock<T>(
    _ f: (inout sending State) throws -> sending T
  ) rethrows -> sending T {
    ll_lock_lock(buffer.elementPointer)
    defer { ll_lock_unlock(buffer.elementPointer) }
    return try f(&buffer.headerPointer.pointee)
  }

  @inlinable
  public func withLockUnchecked<R>(_ f: (inout State) throws -> R) rethrows -> R {
    try buffer.withUnsafeMutablePointers { state, lock in
      ll_lock_lock(lock)
      defer { ll_lock_unlock(lock) }
      return try f(&state.pointee)
    }
  }

  @inlinable
  public func withLockIfAvailable<R>(_ f: (inout sending State) throws -> sending R) rethrows
    -> sending R? {
    guard ll_lock_trylock(buffer.elementPointer) else {
      return nil
    }
    defer { ll_lock_unlock(buffer.elementPointer) }
    return try f(&buffer.headerPointer.pointee)
  }

  @inlinable
  public func withLockIfAvailableUnchecked<R>(_ f: (inout State) throws -> R) rethrows -> R? {
    try buffer.withUnsafeMutablePointers { state, lock in
      guard ll_lock_trylock(lock) else {
        return nil
      }
      defer { ll_lock_unlock(lock) }
      return try f(&state.pointee)
    }
  }

  @inlinable
  public func precondition(_ condition: Ownership) {
    buffer.withUnsafeMutablePointerToElements { lock in
      switch condition {
      case .owner:
        ll_lock_assert_owner(lock)
      case .notOwner:
        ll_lock_assert_not_owner(lock)
      }
    }
  }
}

extension AllocatedUnfairLock where State == Void {
  @inlinable
  public init() {
    self.init(uncheckedState: ())
  }

  @inlinable
  public func withLockUnchecked<R>(_ f: () throws -> R) rethrows -> R {
    try withLockUnchecked { _ in try f() }
  }

  @inlinable
  public func withLock<R>(_ f: () throws -> sending R) rethrows -> sending R {
    ll_lock_lock(buffer.elementPointer)
    defer { ll_lock_unlock(buffer.elementPointer) }
    return try f()
  }

  @inlinable
  public func withLockIfAvailableUnchecked<R>(_ f: () throws -> R) rethrows -> R? {
    try withLockIfAvailableUnchecked { _ in try f() }
  }

  @inlinable
  public func withLockIfAvailable<R: Sendable>(_ f: @Sendable () throws -> R) rethrows -> R? {
    guard ll_lock_trylock(buffer.elementPointer) else {
      return nil
    }
    defer { ll_lock_unlock(buffer.elementPointer) }
    return try f()
  }

  @inlinable
  public func lock() {
    buffer.withUnsafeMutablePointerToElements { lock in
      ll_lock_lock(lock)
    }
  }

  @inlinable
  public func unlock() {
    buffer.withUnsafeMutablePointerToElements { lock in
      ll_lock_unlock(lock)
    }
  }

  @inlinable
  public func lockIfAvailable() -> Bool {
    buffer.withUnsafeMutablePointerToElements { lock in
      ll_lock_trylock(lock)
    }
  }
}

extension AllocatedUnfairLock where State: Sendable {
  @inlinable
  public init(initialState: State) {
    self.init(uncheckedState: initialState)
  }
}

extension ManagedBuffer {
  @inlinable
  var headerPointer: UnsafeMutablePointer<Header> {
    withUnsafeMutablePointerToHeader { $0 }
  }

  @inlinable
  var elementPointer: UnsafeMutablePointer<Element> {
    withUnsafeMutablePointerToElements { $0 }
  }
}

/// This type is just a placeholder, sized as a union of `os_unfair_lock_s`
/// and `OSSpinLock` (both are a 32 bits integers).
@usableFromInline
typealias LowLevelLock = UInt32

@inlinable
func ll_lock_init(_ lock: UnsafeMutablePointer<LowLevelLock>) {
  let initValue: LowLevelLock
  if #available(iOS 10, tvOS 10, macOS 10.12, *) {
    initValue = os_unfair_lock_s()._os_unfair_lock_opaque
  } else {
    initValue = LowLevelLock(bitPattern: OSSpinLock())
  }
  lock.initialize(to: initValue)
}

@inlinable
func ll_lock_lock(_ lock: UnsafeMutablePointer<LowLevelLock>) {
  if #available(iOS 10, tvOS 10, macOS 10.12, *) {
    os_unfair_lock_lock(
      UnsafeMutableRawPointer(lock)
        .assumingMemoryBound(to: os_unfair_lock_s.self)
    )
  } else {
    OSSpinLockLock(UnsafeMutableRawPointer(lock).assumingMemoryBound(to: OSSpinLock.self))
  }
}

@inlinable
func ll_lock_unlock(_ lock: UnsafeMutablePointer<LowLevelLock>) {
  if #available(iOS 10, tvOS 10, macOS 10.12, *) {
    os_unfair_lock_unlock(
      UnsafeMutableRawPointer(lock)
        .assumingMemoryBound(to: os_unfair_lock_s.self)
    )
  } else {
    OSSpinLockUnlock(UnsafeMutableRawPointer(lock).assumingMemoryBound(to: OSSpinLock.self))
  }
}

@inlinable
func ll_lock_trylock(_ lock: UnsafeMutablePointer<LowLevelLock>) -> Bool {
  if #available(iOS 10, tvOS 10, macOS 10.12, *) {
    return os_unfair_lock_trylock(
      UnsafeMutableRawPointer(lock)
        .assumingMemoryBound(to: os_unfair_lock_s.self)
    )
  } else {
    return OSSpinLockTry(UnsafeMutableRawPointer(lock).assumingMemoryBound(to: OSSpinLock.self))
  }
}

@inlinable
func ll_lock_assert_owner(_ lock: UnsafeMutablePointer<LowLevelLock>) {
  if #available(iOS 10, tvOS 10, macOS 10.12, *) {
    os_unfair_lock_assert_owner(
      UnsafeMutableRawPointer(lock)
        .assumingMemoryBound(to: os_unfair_lock_s.self)
    )
  } else {
    // no api
  }
}

@inlinable
func ll_lock_assert_not_owner(_ lock: UnsafeMutablePointer<LowLevelLock>) {
  if #available(iOS 10, tvOS 10, macOS 10.12, *) {
    os_unfair_lock_assert_not_owner(
      UnsafeMutableRawPointer(lock)
        .assumingMemoryBound(to: os_unfair_lock_s.self)
    )
  } else {
    // no api
  }
}
