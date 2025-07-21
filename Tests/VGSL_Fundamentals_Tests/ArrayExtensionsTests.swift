// Copyright 2018 Yandex LLC. All rights reserved.

@testable import VGSLFundamentals

import XCTest

final class ArrayExtensionsTests: XCTestCase {
  func test_endsWith() {
    var arr = [1, 2, 3, 4]

    XCTAssertTrue(arr.endsWith([]))
    XCTAssertTrue(arr.endsWith([3, 4]))
    XCTAssertTrue(arr.endsWith([1, 2, 3, 4]))

    XCTAssertFalse(arr.endsWith([3]))
    XCTAssertFalse(arr.endsWith([2, 4]))
    XCTAssertFalse(arr.endsWith([0, 1, 2, 3, 4]))

    arr = []

    XCTAssertTrue(arr.endsWith([]))
    XCTAssertFalse(arr.endsWith([0]))
    XCTAssertFalse(arr.endsWith([1, 2, 3]))
  }

  func test_isPermutation() {
    let arr = [1, 2, 3]

    XCTAssertTrue(arr.isPermutation(of: [1, 2, 3]))
    XCTAssertTrue(arr.isPermutation(of: [1, 3, 2]))
    XCTAssertTrue(arr.isPermutation(of: [2, 1, 3]))
    XCTAssertTrue(arr.isPermutation(of: [2, 3, 1]))
    XCTAssertTrue(arr.isPermutation(of: [3, 1, 2]))
    XCTAssertTrue(arr.isPermutation(of: [3, 2, 1]))

    XCTAssertFalse(arr.isPermutation(of: []))
    XCTAssertFalse(arr.isPermutation(of: [1, 2, 4]))
    XCTAssertFalse(arr.isPermutation(of: [1, 2, 3, 4]))
    XCTAssertFalse(arr.isPermutation(of: [1, 2]))
  }

  func test_move() {
    XCTAssertEqual(
      modified(data) { $0.move(from: 0, to: 0) },
      data
    )
    XCTAssertEqual(
      modified(data) { $0.move(from: 2, to: 2) },
      data
    )
    XCTAssertEqual(
      modified(data) { $0.move(from: 5, to: 5) },
      data
    )
    XCTAssertEqual(
      modified(data) { $0.move(from: 0, to: 5) },
      [1, 2, 3, 4, 5, 0]
    )
    XCTAssertEqual(
      modified(data) { $0.move(from: 5, to: 0) },
      [5, 0, 1, 2, 3, 4]
    )
    XCTAssertEqual(
      modified(data) { $0.move(from: 2, to: 4) },
      [0, 1, 3, 4, 2, 5]
    )
    XCTAssertEqual(
      modified(data) { $0.move(from: 3, to: 1) },
      [0, 3, 1, 2, 4, 5]
    )
  }
}

private let data = [0, 1, 2, 3, 4, 5]
