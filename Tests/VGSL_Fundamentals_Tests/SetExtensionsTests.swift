// Copyright 2018 Yandex LLC. All rights reserved.

@testable import VGSLFundamentals

import XCTest

final class SetExtensionsTests: XCTestCase {
  func testMultipleUnion() {
    let sets: [Set<Int>] = [
      [1, 2, 3],
      [3, 4, 5],
      [5, 6, 7],
      [5, 6, 7],
    ]
    XCTAssertEqual(Set<Int>.union(sets), [1, 2, 3, 4, 5, 6, 7])

    let setOfSets: Set<Set<Int>> = [[1, 2], [2, 3]]
    XCTAssertEqual(Set<Int>.union(setOfSets), [1, 2, 3])
  }
}
