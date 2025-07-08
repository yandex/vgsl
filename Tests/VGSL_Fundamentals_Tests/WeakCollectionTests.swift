// Copyright 2016 Yandex LLC. All rights reserved.

import XCTest

import VGSLFundamentals

private protocol TestProtocol: AnyObject {
  var dummy: Int { get }
}

private class TestClass: TestProtocol {
  var dummy: Int = 0
}

final class WeakCollectionTests: XCTestCase {
  func test_WeakCollectionContainsWeakReferences() {
    var weakCollection = WeakCollection<TestProtocol>()
    let object = TestClass()
    (0..<5).forEach { $0 == 2 ? weakCollection.append(object) : weakCollection.append(TestClass()) }

    let nonNilArray = weakCollection.compactMap { $0 }
    XCTAssertEqual(nonNilArray.count, 1)
    XCTAssertTrue(nonNilArray.first! === object)
  }

  func test_AppendingToWeakCollection() {
    var weakCollection = WeakCollection<TestProtocol>()
    let object = TestClass()

    weakCollection.append(object)

    let nonNilArray = weakCollection.compactMap { $0 }
    XCTAssertEqual(nonNilArray.count, 1)
    XCTAssertTrue(nonNilArray.first! === object)
  }

  func test_WhenAppendsObject_RemovesDeadReferences() {
    var weakCollection = WeakCollection<TestProtocol>()
    weakCollection.append(TestClass())
    let strongInstance = TestClass()
    weakCollection.forEach { XCTAssertNil($0) } // ensure has nil reference

    weakCollection.append(strongInstance)

    var closureCalled = false
    weakCollection.forEach {
      XCTAssertFalse(closureCalled)
      XCTAssert($0 === strongInstance)
      closureCalled = true
    }
    XCTAssertTrue(closureCalled)
  }

  func test_RemovingFromWeakCollection() {
    var weakCollection = WeakCollection<TestProtocol>()
    let object = TestClass()

    weakCollection.append(object)
    weakCollection.remove(object)

    XCTAssertTrue(weakCollection.map { $0 }.isEmpty)

    weakCollection.append(object)
    weakCollection.remove { $0.dummy == 0 }

    XCTAssertTrue(weakCollection.map { $0 }.isEmpty)
  }

  func test_ConstructingFromArrayLiteral() {
    let object1 = TestClass()
    let object2 = TestClass()
    let object3 = TestClass()

    let weakCollection: WeakCollection<TestProtocol> = [object1, object2, object3]

    zip(weakCollection.compactMap { $0 }, [object1, object2, object3])
      .forEach { XCTAssertTrue($0 === $1) }
  }

  func test_ContainsInEmpty_ReturnsFalse() {
    let weakCollection = WeakCollection<TestProtocol>()
    let object = TestClass()
    XCTAssertFalse(weakCollection.contains(object))
  }

  func test_ContainsTheObject_ReturnsTrue() {
    var weakCollection = WeakCollection<TestProtocol>()
    let object = TestClass()
    weakCollection.append(object)
    XCTAssertTrue(weakCollection.contains(object))
  }

  func test_ContainsTheObjectWasRemoved_ReturnsFalse() {
    var weakCollection = WeakCollection<TestProtocol>()
    let object = TestClass()
    weakCollection.append(object)
    weakCollection.remove(object)
    XCTAssertFalse(weakCollection.contains(object))
  }
}
