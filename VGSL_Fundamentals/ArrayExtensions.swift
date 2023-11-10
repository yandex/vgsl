// Copyright 2015 Yandex LLC. All rights reserved.

// TODO(dmt021): @_spi(Extensions)
extension Array {
  @inlinable
  public func iterativeFlatMap<T>(_ transform: (Element, Index) throws -> T?) rethrows -> [T] {
    var result = [T]()
    result.reserveCapacity(count)
    for (index, item) in self.enumerated() {
      if let transformedItem = try transform(item, index) {
        result.append(transformedItem)
      }
    }
    return result
  }

  @inlinable
  public func toDictionary<K, V>() -> [K: V] where Element == (K, V?) {
    var dict = [K: V]()
    forEach { key, value in
      dict[key] = value
    }
    return dict
  }

  public func find<T>(_ transform: (Element) -> T?) -> T? {
    for item in self {
      if let r = transform(item) {
        return r
      }
    }
    return nil
  }

  public func findAll<T>(_ transform: (Element) -> T?) -> [T] {
    var result = [T]()
    forEach {
      if let found = transform($0) {
        result += found
      }
    }
    return result
  }
}

// TODO(dmt021): @_spi(Extensions)
extension Array where Element: Equatable {
  @inlinable
  public func endsWith(_ other: [Element]) -> Bool {
    Array(self.suffix(other.count)) == other
  }
}

// TODO(dmt021): @_spi(Extensions)
extension Array where Element: Hashable {
  @inlinable
  public func isPermutation(of other: Array) -> Bool {
    let set = Set(self)
    let otherSet = Set(other)
    let diff = set.symmetricDifference(otherSet)
    return diff.isEmpty
  }

  @inlinable
  public var uniqueElements: [Element] {
    Array(Set(self))
  }
}

// TODO(dmt021): @_spi(Extensions)
extension Array where Element: AnyObject {
  @inlinable
  public func isEqualByReferences(_ rhs: [Element]) -> Bool {
    guard count == rhs.count else { return false }

    for pair in zip(self, rhs) {
      guard pair.0 === pair.1 else {
        return false
      }
    }

    return true
  }
}

@inlinable
public func == <T: Equatable>(lhs: [T], rhs: [T?]) -> Bool {
  let nonOptionalRhs = rhs.compactMap { $0 }
  guard nonOptionalRhs.count == rhs.count else { return false }

  return lhs == nonOptionalRhs
}

@inlinable
public func == <T: Equatable>(lhs: [T?], rhs: [T]) -> Bool {
  let nonOptionalLhs = lhs.compactMap { $0 }
  guard nonOptionalLhs.count == lhs.count else { return false }

  return rhs == nonOptionalLhs
}

@inlinable
public func == <A: Equatable, B: Equatable>(lhs: [(A, B)], rhs: [(A, B)]) -> Bool {
  guard lhs.count == rhs.count else {
    return false
  }

  for pair in zip(lhs, rhs) {
    guard pair.0 == pair.1 else {
      return false
    }
  }

  return true
}

@inlinable
public func != <A: Equatable, B: Equatable>(lhs: [(A, B)], rhs: [(A, B)]) -> Bool {
  !(lhs == rhs)
}

@inlinable
public func arraysEqual<T>(_ lhs: [T], _ rhs: [T], equalityTest: (T, T) -> Bool) -> Bool {
  guard lhs.count == rhs.count else { return false }
  return zip(lhs, rhs).first { equalityTest($0.0, $0.1) == false } == nil ? true : false
}

@inlinable
public func == <A: Equatable, B: Equatable, C: Equatable>(
  _ lhs: [(A, B, C)],
  _ rhs: [(A, B, C)]
) -> Bool {
  arraysEqual(lhs, rhs, equalityTest: ==)
}
