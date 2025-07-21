// Copyright 2018 Yandex LLC. All rights reserved.

@testable import VGSLFundamentals

import XCTest

final class RangeExtensionsTests: XCTestCase {
  func testExtended() {
    XCTAssertEqual((0..<1).extended(toContain: 3..<5), 0..<5)
    XCTAssertEqual((2..<4).extended(toContain: 3..<6), 2..<6)
    XCTAssertEqual((0..<10).extended(toContain: 1..<2), 0..<10)
    XCTAssertEqual((0..<10).extended(toContain: -2 ..< -1), -2..<10)
  }
}
