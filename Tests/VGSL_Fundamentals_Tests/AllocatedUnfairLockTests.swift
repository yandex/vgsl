// Copyright 2022 Yandex LLC. All rights reserved.

@testable import VGSLFundamentals

import XCTest

final class AllocatedUnfairLockSendableTests: XCTestCase, @unchecked Sendable {
  private let lock = AllocatedUnfairLock(initialState: 42)

  func test_withLock_ReturnsResult() {
    let result = lock.withLock { $0 }
    XCTAssertEqual(result, 42)
  }

  func test_withLock_MutatesState() {
    lock.withLock { state in
      state += 1
    }
    let result = lock.withLock { $0 }
    XCTAssertEqual(result, 43)
  }

  func test_withLockIfAvailable_WhenNotLocked_RunsClosureAndReturnsResult() {
    let result = lock.withLockIfAvailable { $0 }
    XCTAssertEqual(result, 42)
  }

  func test_withLockIfAvailable_WhenLocked_ReturnsNil() {
    let result = lock.withLock { _ in
      DispatchQueue.global().sync {
        lock.withLockIfAvailable { $0 }
      }
    }
    XCTAssertNil(result)
  }
}

final class AllocatedUnfairLockNotSendableTests: XCTestCase, @unchecked Sendable {
  private let lock = AllocatedUnfairLock(uncheckedState: NSMutableAttributedString(string: "hello"))

  func test_withLock_ReturnsResult() {
    let result = lock.withLockUnchecked { $0 }
    XCTAssertEqual(result.string, "hello")
  }

  func test_withLock_MutatesState() {
    lock.withLock { state in
      state.append(NSAttributedString(string: "world"))
    }
    let result = lock.withLockUnchecked { $0 }
    XCTAssertEqual(result.string, "helloworld")
  }

  func test_withLockIfAvailable_WhenNotLocked_RunsClosureAndReturnsResult() {
    let result = lock.withLockIfAvailableUnchecked { $0 }
    XCTAssertEqual(result?.string, "hello")
  }

  func test_withLockIfAvailable_WhenLocked_ReturnsNil() {
    let result = lock.withLock { _ in
      DispatchQueue.global().sync {
        lock.withLockIfAvailable { _ in 42 }
      }
    }
    XCTAssertNil(result)
  }
}

final class AllocatedUnfairLockVoidTests: XCTestCase, @unchecked Sendable {
  private let lock = AllocatedUnfairLock<Void>()

  func test_lock_tryLock() {
    lock.lock()
    var result = lock.lockIfAvailable()
    XCTAssertFalse(result)

    lock.unlock()
    result = lock.lockIfAvailable()
    XCTAssertTrue(result)

    lock.unlock()
  }

  func test_withLock() {
    let result = lock.withLock { 42 }
    XCTAssertEqual(result, 42)
  }

  func test_withLockIfAvailable_WhenNotLocked_RunsClosureAndReturnsResult() {
    let result = lock.withLockIfAvailable { 42 }
    XCTAssertEqual(result, 42)
  }

  func test_withLockIfAvailable_WhenLocked_ReturnsNil() {
    let result = lock.withLock {
      DispatchQueue.global().sync {
        lock.withLockIfAvailable { 42 }
      }
    }
    XCTAssertNil(result)
  }
}

final class AllocatedUnfairLockStressTests: XCTestCase {
  private struct State: Equatable {
    var a: UInt64 = 0
    var b: UInt64 = 0
    var c: UInt64 = 0
  }

  private let lock = AllocatedUnfairLock(initialState: State())

  func test_stress() {
    let cpuCount = ProcessInfo.processInfo.processorCount
    let rounds = 10000
    let group = DispatchGroup()
    for _ in 0..<cpuCount {
      group.enter()
      DispatchQueue.global(qos: .userInteractive).async { [lock] in
        for _ in 0..<rounds {
          lock.withLock { state in
            state.a += 1
            state.b += state.a
            state.c += state.b
          }
        }
        group.leave()
      }
    }
    group.wait()
    let result = lock.withLock { $0 }
    let a = UInt64(cpuCount * rounds)
    let b = a * (a + 1) / 2
    let c = b * (a + 2) / 3
    XCTAssertEqual(result, State(
      a: a,
      b: b,
      c: c
    ))
  }
}
