// Copyright 2019 Yandex LLC. All rights reserved.

import XCTest

@_spi(Extensions)
import VGSLFundamentals

final class SequenceExtensionsTests: XCTestCase {
  func test_Categorize() {
    let (even, odd) = [1, 2, 3, 4, 5, 6, 7, 8].categorize { $0 % 2 == 0 }
    XCTAssertEqual(even, [2, 4, 6, 8])
    XCTAssertEqual(odd, [1, 3, 5, 7])
  }

  func test_Unzip() {
    let array = [(1, 2), (3, 4), (5, 6)]
    let (odds, even) = unzip(array)

    XCTAssertEqual(odds, [1, 3, 5])
    XCTAssertEqual(even, [2, 4, 6])
  }

  func test_MaxElementsByScoringFunction_WhenInputContainsSeveralElements_ReturnsArrayOfElementsWithMaximizedScore(
  ) {
    let array = [0, 1]

    let result = array.maxElements(by: { $0 })

    XCTAssertEqual(result, [1])
  }

  func test_MaxElementsByScoringFunction_WhenInputIsEmpty_ReturnsEmptyArray() {
    let emptyArray = [Int]()

    let result = emptyArray.maxElements(by: { $0 })

    XCTAssertTrue(result.isEmpty)
  }

  func test_MaxElementsByScoringFunction_WhenInputContainsOnlyOneElement_ReturnsIt() {
    let array = [0]

    let result = array.maxElements(by: { $0 })

    XCTAssertEqual(result, [0])
  }

  func test_MaxElementsByScoringFunction_WhenInputContainsSeveralElementsWithSameScore_ReturnsAllOfThem(
  ) {
    let array = [0, 0]

    let result = array.maxElements(by: { $0 })

    XCTAssertEqual(result, [0, 0])
  }

  func test_Group_WhenEmptySequence_ReturnsEmptyArray() {
    let array = [Int]()

    let result = array.group(batchSize: 3)

    XCTAssertTrue(result.isEmpty)
  }

  func test_Group_WhenSequenceContainsOneBatch_ReturnsArrayWithOneGroup() {
    let array = [1, 2, 3]

    let result = array.group(batchSize: 3)

    XCTAssertEqual(result, [[1, 2, 3]])
  }

  func test_Group_WhenSequenceContainsTwoBatches_ReturnsArrayWithTwoGroups() {
    let array = [1, 2, 3, 4, 5, 6]

    let result = array.group(batchSize: 3)

    XCTAssertEqual(result, [[1, 2, 3], [4, 5, 6]])
  }

  func test_Group_WhenSequenceContainsHalfBatch_ReturnsArrayWithOneGroup() {
    let array = [1, 2]

    let result = array.group(batchSize: 3)

    XCTAssertEqual(result, [[1, 2]])
  }

  func test_Group_WhenSequenceContainsOneAndHalfBatch_ReturnsArrayWithOneAndHalfGroup() {
    let array = [1, 2, 3, 4, 5]

    let result = array.group(batchSize: 3)

    XCTAssertEqual(result, [[1, 2, 3], [4, 5]])
  }

  func test_CountElements_WhenInputIsEmpty_ReturnsEmptyDictionary() {
    let array = [Int]()

    let result = array.countElements()

    XCTAssertTrue(result.isEmpty)
  }

  func test_CountElements_WhenInputContainsSeveralElements_ReturnsADictionaryWithKeysAreElementsAndValuesAreCountOfOccrurancesOfTheElement(
  ) {
    let array = [0, 1, 0, 1, 0]

    let result = array.countElements()

    let expectedResult = [
      0: 3,
      1: 2,
    ]
    XCTAssertEqual(result, expectedResult)
  }

  func test_ToDictionaryReturnsEmptyDictionaryFromEmptySequence() {
    let sequence = [Int]()
    func keyMapper(number: Int) -> String {
      "\(number)"
    }
    func valueMapper(number: Int) -> String {
      "\(number + 47)"
    }

    let result = sequence.toDictionary(keyMapper: keyMapper, valueMapper: valueMapper)

    XCTAssertTrue(result.keys.isEmpty)
  }

  func test_ToDictionaryReturnsProperDictionary() {
    let sequence = 1...10
    var expectedResult = [String: String]()
    func keyMapper(number: Int) -> String {
      "\(number)"
    }
    func valueMapper(number: Int) -> String {
      "\(number + 47)"
    }
    for number in sequence {
      expectedResult[keyMapper(number: number)] = valueMapper(number: number)
    }

    let result = sequence.toDictionary(keyMapper: keyMapper, valueMapper: valueMapper)

    XCTAssertEqual(result, expectedResult)
  }

  func test_UnzipReturnsProperArrays() {
    let zipped = [(0, 1), (2, 3), (4, 5)]
    let (even, odd) = unzip(zipped)

    XCTAssertEqual(even, [0, 2, 4])
    XCTAssertEqual(odd, [1, 3, 5])
  }

  func test_Uniqued_WhenSequenceWithDuplicates_ReturnsArrayWithoutDuplicates() {
    let array = [5, 2, 2, 3, 1, 4, 4, 4]

    let result = array.uniqued()

    XCTAssertEqual(result, [5, 2, 3, 1, 4])
  }

  func test_Uniqued_WhenSequenceWithProjectedDuplicates_ReturnsArrayWithoutDuplicates() {
    let array = [(5, 1), (2, 2), (2, 3), (3, 4), (1, 5), (4, 6), (4, 7), (4, 8)]

    let result = array.uniqued(on: { $0.0 })

    XCTAssertTrue(arraysEqual(result, [(5, 1), (2, 2), (3, 4), (1, 5), (4, 6)], equalityTest: ==))
  }

  func test_Uniqued_WhenEmptySequence_ReturnsEmptyArray() {
    let array = [Int]()

    let result = array.uniqued()

    XCTAssertTrue(result.isEmpty)
  }

  func test_Uniqued_WhenSequenceWithoutDuplicates_ReturnsArrayWithSameSequence() {
    let array = [1, 2, 3, 4, 5]

    let result = array.uniqued()

    XCTAssertEqual(result, array)
  }

  func test_Uniqued_WhenSequenceWithoutProjectedDuplicates_ReturnsArrayWithoutDuplicates() {
    let array = [(5, 1), (2, 2), (2, 3), (3, 4), (1, 5), (4, 6), (4, 7), (4, 8)]

    let result = array.uniqued(on: { $0.1 })

    XCTAssertTrue(arraysEqual(result, array, equalityTest: ==))
  }

  func test_ConcurrentMap_PreservesOrder() async throws {
    let initialArray = [1, 2, 3, 4, 5]

    let result = await initialArray.map(concurrencyLimit: 5) {
      $0 * 2
    }

    XCTAssertEqual(result, [2, 4, 6, 8, 10])
  }

  func test_ConcurrentMap_ErrorHandling() async throws {
    struct Foo: Error {}
    do {
      _ = try await (0..<25).map(concurrencyLimit: 10, transform: {
        if $0 == 13 {
          throw Foo()
        }
      })
      XCTFail("Error not thrown")
    } catch _ as Foo {}
  }
}

private func arraysEqual<T>(_ lhs: [T], _ rhs: [T], equalityTest: (T, T) -> Bool) -> Bool {
  guard lhs.count == rhs.count else { return false }
  return zip(lhs, rhs).first { equalityTest($0.0, $0.1) == false } == nil ? true : false
}

private actor Counter {
  private var count = 0

  private var counts: [Int] = []

  var avgCount: Double {
    counts.map { Double($0) / Double(counts.count) }.reduce(0, +)
  }

  func incr() {
    count += 1
    XCTAssertLessThanOrEqual(count, 10)
    counts.append(count)
  }

  func decr() {
    count -= 1
  }
}
