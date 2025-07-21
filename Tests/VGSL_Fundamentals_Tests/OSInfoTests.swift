// Copyright 2022 Yandex LLC. All rights reserved.

@testable import VGSLFundamentals

import Foundation
import XCTest

final class OSInfoTests: XCTestCase {
  func test_OSVersionMatchesWithFoundation() {
    let nsVersion = ProcessInfo.processInfo.operatingSystemVersion
    let expected = OSVersion(
      nsVersion.majorVersion,
      nsVersion.minorVersion,
      nsVersion.patchVersion
    )
    OSInfo.restoreSystemCurrent()
    let actual = OSInfo.current.version
    XCTAssertEqual(actual, expected)
  }

  func test_VersionComparesLexicographically() {
    XCTAssertLessThan(OSVersion(0, 0, 2), OSVersion(0, 0, 10))
    XCTAssertLessThan(OSVersion(0, 2, 0), OSVersion(0, 10, 0))
    XCTAssertLessThan(OSVersion(2, 0, 0), OSVersion(10, 0, 0))
    XCTAssertGreaterThanOrEqual(OSVersion(0, 1, 0), OSVersion(0, 0, 10))
    XCTAssertGreaterThanOrEqual(OSVersion(1, 0, 0), OSVersion(0, 10, 0))
  }
}
