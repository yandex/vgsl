// Copyright 2021 Yandex LLC. All rights reserved.

// TODO(dmt021): @_spi(Extensions)
extension Sequence {
  public func group(batchSize: Int) -> [[Element]] {
    var result = [[Element]]()
    var iterator = makeIterator()
    var currentBatch = [Element]()
    while let currentItem = iterator.next() {
      if currentBatch.count == batchSize {
        result.append(currentBatch)
        currentBatch = [Element]()
      }
      currentBatch.append(currentItem)
    }
    if !currentBatch.isEmpty {
      result.append(currentBatch)
    }
    return result
  }

  /// Returns array of unique element based on comparator
  /// Complexity: O(n^2)
  @inlinable
  public func uniqued(comparator: @escaping (Element, Element) -> Bool) -> [Element] {
    var result: [Element] = []
    for element in self {
      if result.contains(where: { comparator(element, $0) }) {
        continue
      }
      result.append(element)
    }
    return result
  }

  @inlinable
  public func uniqued<Subject: Hashable>(
    on projection: (Element) -> Subject
  ) -> [Element] {
    var seen: Set<Subject> = []
    var result: [Element] = []
    for element in self {
      if seen.insert(projection(element)).inserted {
        result.append(element)
      }
    }
    return result
  }

  @inlinable
  public func firstMatch(_ predicate: (Element) -> Bool) -> Element? {
    for item in self {
      if predicate(item) {
        return item
      }
    }

    return nil
  }

  @inlinable
  public func allPass(predicate: (Element) throws -> Bool) rethrows -> Bool {
    try !contains { try !predicate($0) }
  }

  @inlinable
  public func maxElements<T: Comparable>(by scoringFunction: (Element) -> T) -> [Element] {
    let scores = map(scoringFunction)
    guard let maxScore = scores.max() else {
      return []
    }
    return zip(scores, self)
      .filter { $0.0 == maxScore }
      .map { $0.1 }
  }

  @inlinable
  public func map<Value>(to path: KeyPath<Element, Value>) -> [Value] {
    map { $0[keyPath: path] }
  }

  @inlinable
  public func reduce<Result, Value>(
    _ initial: Result,
    _ nextPartialResult: (Result, Value) throws -> Result,
    by path: KeyPath<Element, Value>
  ) rethrows -> Result {
    try reduce(initial) { try nextPartialResult($0, $1[keyPath: path]) }
  }

  @inlinable
  public func toDictionary<KeyType, ValueType>(
    keyMapper: (Element) throws -> KeyType,
    valueMapper: (Element) throws -> ValueType
  ) rethrows -> [KeyType: ValueType] {
    var result = [:] as [KeyType: ValueType]
    for element in self {
      result[try keyMapper(element)] = try valueMapper(element)
    }
    return result
  }

  @inlinable
  public func categorize(
    _ predicate: (Element) -> Bool
  ) -> (onTrue: [Element], onFalse: [Element]) {
    var res = (onTrue: [Element](), onFalse: [Element]())
    for el in self {
      if predicate(el) {
        res.onTrue.append(el)
      } else {
        res.onFalse.append(el)
      }
    }
    return res
  }
}

// TODO(dmt021): @_spi(Extensions)
extension Sequence where Element: Hashable {
  @inlinable
  public func makeDictionary<T>(withValueForKey valueForKey: (Element) throws -> T?) rethrows
    -> [Element: T] {
    var result: [Element: T] = [:]

    for element in self {
      result[element] = try valueForKey(element)
    }

    return result
  }

  @inlinable
  public func countElements() -> [Element: Int] {
    reduce(into: [Element: Int]()) { $0[$1, default: 0] += 1 }
  }

  @inlinable
  public func uniqued() -> [Element] {
    uniqued(on: { $0 })
  }
}

// TODO(dmt021): @_spi(Extensions)
extension Sequence where Element: Numeric {
  @inlinable
  public var partialSums: [Element] {
    var sums = [Element]()
    var currentSum: Element = 0
    forEach {
      currentSum += $0
      sums.append(currentSum)
    }
    return sums
  }
}

@inlinable
public func unzip<SequenceType: Sequence, E1, E2>(
  _ sequence: SequenceType
) -> ([E1], [E2]) where SequenceType.Element == (E1, E2) {
  return (sequence.map { $0.0 }, sequence.map { $0.1 })
}

@inlinable
public func walk<IteratorType: IteratorProtocol, Element>(
  iterator: IteratorType,
  elementAction: @escaping (Element, @escaping () -> Void) -> Void,
  noElementAction: @escaping () -> Void = {},
  asyncMainThreadRunner: @escaping (@escaping () -> Void) -> Void
) where IteratorType.Element == Element {
  var it = iterator
  guard let element = it.next() else {
    noElementAction()
    return
  }
  elementAction(element) {
    asyncMainThreadRunner {
      walk(
        iterator: it,
        elementAction: elementAction,
        noElementAction: noElementAction,
        asyncMainThreadRunner: asyncMainThreadRunner
      )
    }
  }
}

@inlinable
public func walkSync<IteratorType: IteratorProtocol, Element>(
  iterator: IteratorType,
  elementAction: @escaping (Element, @escaping (Bool) -> Void) -> Void,
  noElementAction: @escaping () -> Void = {}
) where IteratorType.Element == Element {
  var it = iterator
  func walkSync() {
    while let element = it.next() {
      var inSyncCall = true
      var syncResult: Bool?
      elementAction(element) { isHandled in
        if inSyncCall {
          syncResult = isHandled
          return
        }

        if !isHandled {
          walkSync()
        }
      }
      inSyncCall = false

      if let syncResult = syncResult {
        if syncResult {
          return
        } else {
          continue
        }
      } else {
        return
      }
    }

    noElementAction()
  }
  walkSync()
}
