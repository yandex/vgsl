// Copyright 2018 Yandex LLC. All rights reserved.

import XCTest

import VGSLFundamentals

final class CommonFunctionsTests: XCTestCase {
  func test_clamp() {
    XCTAssertEqual(5.clamp(1...8), 5)
    XCTAssertEqual(1.clamp(1...8), 1)
    XCTAssertEqual(8.clamp(1...8), 8)
    XCTAssertEqual(0.clamp(1...8), 1)
    XCTAssertEqual(9.clamp(1...8), 8)
  }
}
