// Copyright 2017 Yandex LLC. All rights reserved.

import XCTest

import VGSLFundamentals

final class DictionaryExtensionTests: XCTestCase {
  func test_WhenDictionaryHasStringKeys_CaseInsensitiveSearchReturnsValue() {
    let dictionary = [
      "MultipleCaseKey": 24,
      "SecondMultipleCaseKey": 42,
    ]
    XCTAssertEqual(dictionary.value(forCaseInsensitiveKey: "MULTIPLECASEKEY"), 24)
    XCTAssertEqual(dictionary.value(forCaseInsensitiveKey: "secondMultiplecaseKey"), 42)
  }

  func test_WhenDictionaryHasStringKeysAndKeyToSearchForIsEmpty_CaseInsensitiveSearchReturnsNil() {
    let dictionary = [
      "SomeKey": "SomeValue",
    ]
    XCTAssertNil(dictionary.value(forCaseInsensitiveKey: ""))
  }

  func test_WhenDictionaryHasNonStringKeys_CaseInsensitiveSearchReturnsNil() {
    let dictionary = [
      24: "FirstValue",
      42: "SecondValue",
    ]
    XCTAssertNil(dictionary.value(forCaseInsensitiveKey: 24))
    XCTAssertNil(dictionary.value(forCaseInsensitiveKey: 42))
  }

  func test_WhenDictionaryIsEmpty_CaseInsensitiveSearchReturnsNil() {
    let dictionary = [AnyHashable: Any]()
    XCTAssertNil(dictionary.value(forCaseInsensitiveKey: "One"))
    XCTAssertNil(dictionary.value(forCaseInsensitiveKey: 42))
  }

  func test_LowercasedKeysTransformsKeysToLowercase() {
    let expectedDictionary: [String: String] = [
      "aa": "1",
      "bb": "2",
      "cc": "3",
      "dd": "4",
    ]
    let dictionary: [String: String] = [
      "AA": "1",
      "Bb": "2",
      "cC": "3",
      "dd": "4",
    ]

    XCTAssertEqual(dictionary.lowercasedKeys, expectedDictionary)
  }

  func test_WhenDictionaryInitializedFromKeyValuePairs_UniquingKeysWithLast_AndDuplicatedKeysPassed_RewritesValues(
  ) {
    let expectedDictionary: [String: String] = [
      "aa": "3",
      "bb": "5",
    ]
    let dictionary = Dictionary(duplicatedKeysSeq, uniquingKeysWith: { $1 })

    XCTAssertEqual(dictionary, expectedDictionary)
  }

  func test_WhenDictionaryInitializedFromKeyValue_UniquingKeysWithCombineThrow_AndDuplicatedKeysPassed_ThrowsError(
  ) {
    XCTAssertThrowsError(
      try Dictionary(duplicatedKeysSeq, uniquingKeysWith: Combine.throw)
    ) { error in
      XCTAssertEqual(
        error as? CombineFailure<String>,
        CombineFailure(values: ["1", "3"])
      )
    }
  }

  func test_WhenDictionariesRecursivelyMerges_CaseDictionariesHaveNestingIntersectionDictionaries() {
    let firstDictionary: [String: Any] = ["a": ["b": 3, "c": 4]]
    let secondDictionary: [String: Any] = ["a": ["b": 5, "d": 6]]
    let expectedValue = ["b": 5, "d": 6, "c": 4]

    let mergingValue = firstDictionary.mergingRecursively(secondDictionary)["a"] as! [String: Int]
    XCTAssertEqual(expectedValue, mergingValue)
  }

  func test_WhenDictionariesRecursivelyMerges_CaseValueChangeFromScalarToDictionary() {
    let firstDictionary: [String: Any] = ["a": 0]
    let secondDictionary: [String: Any] = ["a": ["c": 1, "d": 2]]
    let expectedDictionary = ["a": ["c": 1, "d": 2]]

    let mergingDictionary = firstDictionary
      .mergingRecursively(secondDictionary) as! [String: [String: Int]]
    XCTAssertEqual(expectedDictionary, mergingDictionary)
  }

  func test_WhenDictionariesRecursivelyMerges_CaseValueChangeFromDictionaryToScalar() {
    let firstDictionary: [String: Any] = ["a": ["c": 1, "b": 2]]
    let secondDictionary: [String: Any] = ["a": 3]
    let expectedDictionary = ["a": 3]

    let mergingDictionary = firstDictionary.mergingRecursively(secondDictionary) as! [String: Int]
    XCTAssertEqual(expectedDictionary, mergingDictionary)
  }

  func test_WhenDictionariesRecursivelyMerges_CaseOriginalDictionaryIsEmpty() {
    let firstDictionary: [String: Int] = [:]
    let secondDictionary = ["a": 1, "b": 2]
    let expectedDictionary = ["a": 1, "b": 2]

    XCTAssertEqual(expectedDictionary, firstDictionary.mergingRecursively(secondDictionary))
  }

  func test_WhenDictionariesRecursivelyMerges_CaseMergingDictionaryIsEmpty() {
    let firstDictionary = ["a": 1, "b": 2]
    let secondDictionary: [String: Int] = [:]
    let expectedDictionary = ["a": 1, "b": 2]

    XCTAssertEqual(expectedDictionary, firstDictionary.mergingRecursively(secondDictionary))
  }

  func test_WhenDictionariesRecursivelyMerges_CaseDictionaryHaveNestingDisjointDictionaries() {
    let firstDictionary: [String: Any] = ["a": ["b": 1, "c": 2]]
    let secondDictionary: [String: Any] = ["a": ["d": 3, "e": 4]]
    let expectedValue = ["b": 1, "c": 2, "d": 3, "e": 4]

    let mergingValue = firstDictionary.mergingRecursively(secondDictionary)["a"] as! [String: Int]
    XCTAssertEqual(expectedValue, mergingValue)
  }
}

let duplicatedKeysSeq = [
  ("aa", "1"),
  ("bb", "2"),
  ("aa", "3"),
  ("bb", "4"),
  ("bb", "5"),
]
