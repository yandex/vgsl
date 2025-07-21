// Copyright 2021 Yandex LLC. All rights reserved.

import XCTest

@_spi(Extensions)
import VGSLFundamentals

final class ArrayBuilderTests: XCTestCase {
  func test_buildBlock() {
    let actual = Array<Int>.build {
      1
      2
    }
    XCTAssertEqual(actual, [1, 2])
  }

  func test_buildExpression() {
    let actual = Array<Int>.build {
      1
    }
    XCTAssertEqual(actual, [1])
  }

  func test_buildExpressionArray() {
    let actual = Array<Int>.build {
      [1, 2, 3]
    }
    XCTAssertEqual(actual, [1, 2, 3])
  }

  func test_buildExpressionOptional_WithOptional() {
    let actual = Array<Int>.build {
      Int?.some(1)
      nil
    }
    XCTAssertEqual(actual, [1])
  }

  func test_buildExpressionOptional_WithConditionIsMet() {
    let condition = true
    let actual = Array<Int>.build {
      if condition {
        1
      }
    }
    XCTAssertEqual(actual, [1])
  }

  func test_buildExpressionOptional_WithConditionIsNotMet() {
    let condition = false
    let actual = Array<Int>.build {
      if condition {
        1
      }
    }
    XCTAssertEqual(actual, [])
  }

  func test_buildEither_WithConditionIsMet() {
    let condition = true
    let actual = Array<Int>.build {
      if condition {
        1
      } else {
        2
      }
    }
    XCTAssertEqual(actual, [1])
  }

  func test_buildEither_WithConditionIsNotMet() {
    let condition = false
    let actual = Array<Int>.build {
      if condition {
        1
      } else {
        2
      }
    }
    XCTAssertEqual(actual, [2])
  }

  func test_buildArray() {
    let actual = Array<Int>.build {
      for i in 0..<5 {
        i
      }
    }
    XCTAssertEqual(actual, [0, 1, 2, 3, 4])
  }

  func test_ArrayBuilder_build() {
    let actual = ArrayBuilder.build {
      1
      2
      3
    }
    XCTAssertEqual(actual, [1, 2, 3])
  }
}
