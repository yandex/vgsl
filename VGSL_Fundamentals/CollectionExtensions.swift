// Copyright 2021 Yandex LLC. All rights reserved.

// Collection

// TODO(dmt021): @_spi(Extensions)
extension Collection {
  @inlinable
  public func firstMatchWithIndex(
    _ predicate: @escaping (Element) -> Bool
  ) -> (Index, Element)? {
    zip(indices, self).first { predicate($0.1) }
  }

  @inlinable
  public func floorIndex<T: BinaryFloatingPoint>(
    _ index: T
  ) -> Int where Index == Int {
    guard !isEmpty else {
      return startIndex
    }

    let integral = Int(index.rounded(.down))
    return clamp(integral, min: startIndex, max: endIndex.advanced(by: -1))
  }

  @inlinable
  public func ceilIndex<T: BinaryFloatingPoint>(
    _ index: T
  ) -> Int where Index == Int {
    guard !isEmpty else {
      return startIndex
    }

    let integral = Int(index.rounded(.up))
    return clamp(integral, min: startIndex, max: endIndex.advanced(by: -1))
  }
}

// TODO(dmt021): @_spi(Extensions)
extension Collection where Element: Equatable {
  @inlinable
  public func element(after item: Element) -> Element? {
    guard let itemIndex = firstIndex(of: item) else {
      return nil
    }
    let afterIndex = index(after: itemIndex)
    guard afterIndex != endIndex else {
      return nil
    }
    return self[afterIndex]
  }
}

@inlinable
public func reverseIndex<T: Collection>(_ index: T.Index, inCollection collection: T) -> T.Index {
  let distanceToIndex = collection.distance(from: collection.startIndex, to: index)
  return collection.index(collection.endIndex, offsetBy: -(1 + distanceToIndex))
}

// RangeReplaceableCollection

// TODO(dmt021): @_spi(Extensions)
extension RangeReplaceableCollection {
  public init(repeating element: Element, times: UInt) {
    // swiftlint:disable no_direct_use_of_repeating_count_initializer
    self.init(repeating: element, count: Int(times))
    // swiftlint:disable no_direct_use_of_repeating_count_initializer
  }

  /// throws `InvalidArgumentError` when `desiredCount` is less than `count`
  public func paddedAtBeginning(upTo desiredCount: Int, with value: Element) throws -> Self {
    var result = self
    result.insert(
      contentsOf: Array(repeating: value, times: try UInt(value: desiredCount - count)),
      at: startIndex
    )
    return result
  }

  public mutating func move(from: Index, to: Index) {
    insert(remove(at: from), at: to)
  }
}

// TODO(dmt021): @_spi(Extensions)
extension RangeReplaceableCollection where Index == Int {
  @inlinable
  public func stableSort(isLessOrEqual: (Element, Element) -> Bool) -> Self {
    var result = self
    var aux: [Element] = []
    aux.reserveCapacity(Int(count))

    func merge(_ lo: Index, _ mid: Index, _ hi: Index, isLessOrEqual: (Element, Element) -> Bool) {
      aux.removeAll(keepingCapacity: true)

      var i = lo, j = mid
      while i < mid, j < hi {
        if isLessOrEqual(result[i], result[j]) {
          aux.append(result[i])
          i = result.index(after: i)
        } else {
          aux.append(result[j])
          j = result.index(after: j)
        }
      }
      aux.append(contentsOf: result[i..<mid])
      aux.append(contentsOf: result[j..<hi])
      result.replaceSubrange(lo..<hi, with: aux)
    }

    var size = 1
    while size < count {
      for lo in stride(from: startIndex, to: index(endIndex, offsetBy: -size), by: size * 2) {
        merge(
          lo,
          lo.advanced(by: size),
          result.index(lo, offsetBy: size * 2, limitedBy: endIndex) ?? endIndex,
          isLessOrEqual: isLessOrEqual
        )
      }
      size *= 2
    }

    return result
  }
}

@inlinable
public func += <T: RangeReplaceableCollection>(
  collection: inout T, object: T.Element
) {
  collection.append(object)
}

// MutableCollection

// TODO(dmt021): @_spi(Extensions)
extension MutableCollection where Element: MutableCollection {
  @inlinable
  public subscript(coords: (Index, Element.Index)) -> Element.Element {
    get {
      self[coords.0][coords.1]
    }
    set {
      self[coords.0][coords.1] = newValue
    }
  }
}

// RandomAccessCollection

// TODO(dmt021): @_spi(Extensions)
extension RandomAccessCollection {
  public var lastElementIndex: Index? {
    isEmpty ? nil : index(before: endIndex)
  }

  @inlinable
  public func lowerBound(where predicate: (Element) -> Bool) -> Index? {
    guard self.count > 0 else { return nil }
    var l = self.startIndex
    var r = self.index(self.endIndex, offsetBy: -1)
    while self.index(l, offsetBy: 1) < r {
      let distance = self.distance(from: l, to: r)
      let mid = self.index(l, offsetBy: distance / 2)
      if predicate(self[mid]) {
        r = mid
      } else {
        l = mid
      }
    }
    if predicate(self[l]) { return l }
    if predicate(self[r]) { return r }
    return nil
  }

  @inlinable
  public func upperBound(where predicate: (Element) -> Bool) -> Index? {
    guard self.count > 0 else { return nil }
    var l = self.startIndex
    var r = self.index(self.endIndex, offsetBy: -1)
    while self.index(l, offsetBy: 1) < r {
      let distance = self.distance(from: l, to: r)
      let mid = self.index(l, offsetBy: distance / 2)
      if predicate(self[mid]) {
        l = mid
      } else {
        r = mid
      }
    }
    if predicate(self[r]) { return r }
    if predicate(self[l]) { return l }
    return nil
  }
}
