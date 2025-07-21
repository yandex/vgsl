// Copyright 2024 Yandex LLC. All rights reserved.

@testable import VGSLFundamentals

import XCTest

final class URLExtensionsTests: XCTestCase {
  func testResolvingRelativeURLs() {
    let baseURL = URL(fileURLWithPath: "/a/b/c")

    func check(
      url: URL,
      expectedRelativePath: String,
      expectedPath: String
    ) {
      let relativeURL = try! URL.resolveFileURL(url, againstURL: baseURL)
      XCTAssertEqual(relativeURL.relativePath, expectedRelativePath)
      XCTAssertEqual(relativeURL.path, expectedPath)
    }

    check(
      url: URL(fileURLWithPath: "/a/b/c"),
      expectedRelativePath: ".",
      expectedPath: "/a/b/c"
    )

    check(
      url: URL(fileURLWithPath: "/a/b/c/d/e"),
      expectedRelativePath: "d/e",
      expectedPath: "/a/b/c/d/e"
    )

    check(
      url: URL(fileURLWithPath: "/c/b/a"),
      expectedRelativePath: "/c/b/a",
      expectedPath: "/c/b/a"
    )

    let notAFileURL = URL(string: "https://ya.ru")!

    XCTAssertThrowsError(try URL.resolveFileURL(notAFileURL, againstURL: baseURL)) { error in
      XCTAssertEqual(error as? FileURLError, FileURLError.notAFileURL)
    }

    XCTAssertThrowsError(try URL.resolveFileURL(baseURL, againstURL: notAFileURL)) { error in
      XCTAssertEqual(error as? FileURLError, FileURLError.notAFileURL)
    }
  }
}
