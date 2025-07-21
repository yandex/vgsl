// Copyright 2019 Yandex LLC. All rights reserved.

@testable import VGSLFundamentals

import XCTest

final class NonEmptyTests: XCTestCase {
  func test_Collection() {
    let xs = NonEmptyArray(1, 2, 3)

    XCTAssertEqual(3, xs.count)
    XCTAssertEqual(2, xs.first + 1)
    XCTAssertEqual(
      xs,
      NonEmptyArray(NonEmptyArray(1), NonEmptyArray(2), NonEmptyArray(3)).flatMap { $0 }
    )
    XCTAssertEqual(
      NonEmptyArray("1", "2", "3"),
      xs.map(String.init)
    )
    XCTAssertEqual(4, xs.min(by: >) + 1)
    XCTAssertEqual(2, xs.max(by: >) + 1)
    XCTAssertEqual(NonEmptyArray(3, 2, 1), xs.sorted(by: >))
    XCTAssertEqual([1, 2, 3], Array(xs))
    let secondIndex = xs.index(after: xs.startIndex)
    XCTAssertEqual(xs[secondIndex], 2)
    let thirdIndex = xs.index(after: secondIndex)
    XCTAssertEqual(xs[thirdIndex], 3)
  }

  func test_CollectionWithIntIndex() {
    let xs = NonEmptyArray(1, 2, 3)
    XCTAssertEqual(1, xs[0])
    XCTAssertEqual(2, xs[1])
  }

  func test_BidirectionalCollection() {
    let xs = NonEmptyArray(1, 2, 3)
    XCTAssertEqual(4, xs.last + 1)
    XCTAssertEqual(4, NonEmptyArray(3).last + 1)
    let thirdIndex = xs.index(before: xs.endIndex)
    XCTAssertEqual(xs[thirdIndex], 3)
    let secondIndex = xs.index(before: thirdIndex)
    let firstIndex = xs.index(before: secondIndex)
    XCTAssertEqual(firstIndex, xs.startIndex)
  }

  func test_MutableCollection() {
    var xs = NonEmptyArray(1, 2, 3)
    xs[0] = 42
    xs[1] = 43
    XCTAssertEqual(42, xs[0])
    XCTAssertEqual(43, xs[1])
  }

  func test_RangeReplaceableCollection() {
    var xs = NonEmptyArray(1, 2, 3)
    xs.append(4)
    XCTAssertEqual(NonEmptyArray(1, 2, 3, 4), xs)
    xs.append(contentsOf: [5, 6])
    XCTAssertEqual(NonEmptyArray(1, 2, 3, 4, 5, 6), xs)
    xs.insert(0, at: 0)
    XCTAssertEqual(NonEmptyArray(0, 1, 2, 3, 4, 5, 6), xs)
    xs.insert(contentsOf: [-2, -1], at: 0)
    XCTAssertEqual(NonEmptyArray(-2, -1, 0, 1, 2, 3, 4, 5, 6), xs)
    xs.insert(contentsOf: [], at: 0)
    XCTAssertEqual(NonEmptyArray(-2, -1, 0, 1, 2, 3, 4, 5, 6), xs)
    xs.insert(7, at: 8)
    XCTAssertEqual(NonEmptyArray(-2, -1, 0, 1, 2, 3, 4, 5, 6, 7), xs)
    xs.insert(contentsOf: [8, 9], at: 9)
    XCTAssertEqual(NonEmptyArray(-2, -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9), xs)
    xs += [10]
    XCTAssertEqual(NonEmptyArray(-2, -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10), xs)
    XCTAssertEqual(NonEmptyArray(-2, -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11), xs + [11])
  }

  func test_Join() {
    let xs = NonEmptyArray("a", "b", "c")
    XCTAssertEqual(xs.joined(), "abc")
  }

  func test_String() {
    let blob = NonEmptyString("B", "lob")

    XCTAssertEqual(NonEmpty("B", ""), NonEmpty("B"))
    XCTAssertEqual(NonEmpty("B", "LOB"), NonEmpty("B", "lOb").uppercased())
    XCTAssertEqual(NonEmpty("b", "lob"), NonEmpty("B", "lOb").lowercased())
    XCTAssertEqual(
      NonEmpty("B", "lob Blob Blob"),
      NonEmptyArray(blob, blob, blob)
        .joined(separator: " ")
    )
    XCTAssertEqual("Blob", blob.string)
    let emptyString = ""
    let helloString = "Hello"
    XCTAssertNil(NonEmpty(emptyString))
    XCTAssertEqual(NonEmpty(helloString)?.string, helloString)
    XCTAssertEqual(NonEmpty("ß").uppercased().string, "SS")
    let byStringLiteral: NonEmptyString = "Hello"
    XCTAssertEqual(byStringLiteral.string, helloString)
    let byGraphemeCluster = NonEmpty(extendedGraphemeClusterLiteral: "🇸🇬")
    XCTAssertEqual(byGraphemeCluster.string, "🇸🇬")
    let byUnicodeScalar = NonEmpty(unicodeScalarLiteral: "ñ")
    XCTAssertEqual(byUnicodeScalar.string, "ñ")
  }

  func test_Equatable() {
    XCTAssertEqual(NonEmptyArray(1, 2, 3), NonEmptyArray(1, 2, 3))
    XCTAssertNotEqual(NonEmptyArray(1, 2, 3), NonEmptyArray(2, 2, 3))
    XCTAssertNotEqual(NonEmptyArray(1, 2, 3), NonEmptyArray(1, 2, 4))
  }

  func test_Comparable() {
    XCTAssertEqual(2, NonEmptyArray(1, 2, 3).min() + 1)
    XCTAssertEqual(2, NonEmptyArray(3, 2, 1).min() + 1)
    XCTAssertEqual(2, NonEmptyArray(1).min() + 1)
    XCTAssertEqual(4, NonEmptyArray(1, 2, 3).max() + 1)
    XCTAssertEqual(4, NonEmptyArray(3, 2, 1).max() + 1)
    XCTAssertEqual(4, NonEmptyArray(3).max() + 1)
    XCTAssertEqual(NonEmptyArray(1, 2, 3), NonEmptyArray(3, 1, 2).sorted())
    XCTAssertEqual(NonEmptyArray(1), NonEmptyArray(1).sorted())
  }

  func test_Codable() throws {
    let xs = NonEmptyArray(1, 2, 3)

    XCTAssertEqual(
      xs,
      try JSONDecoder().decode(NonEmptyArray<Int>.self, from: JSONEncoder().encode(xs))
    )
    XCTAssertEqual(
      xs,
      try JSONDecoder()
        .decode(NonEmptyArray<Int>.self, from: Data("{\"head\":1,\"tail\":[2,3]}".utf8))
    )
  }

  func test_MutableCollectionWithArraySlice() {
    let numbers = Array(1...10)
    var xs = NonEmpty(0, numbers[5...])
    xs[6] = 43
    XCTAssertEqual(43, xs[6])
    XCTAssertEqual(
      Array(xs),
      [0, 43, 7, 8, 9, 10]
    )
  }
}
