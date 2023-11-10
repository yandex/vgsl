// Copyright 2022 Yandex LLC. All rights reserved.

@inlinable
public func clamp<T: Comparable>(
  _ value: T, min minValue: T, max maxValue: T
) -> T {
  guard minValue <= maxValue else {
    assertionFailure()
    return minValue
  }
  return value.clamp(minValue...maxValue)
}

@inlinable
public func clamp<T: FloatingPoint>(
  _ value: T, min minValue: T, max maxValue: T
) -> T
  where T.Stride: ExpressibleByFloatLiteral {
  guard minValue <= maxValue else {
    assert(minValue.isApproximatelyLessOrEqualThan(maxValue))
    return minValue
  }
  return value.clamp(minValue...maxValue)
}

// TODO(dmt021): @_spi(Extensions)
extension Comparable {
  public func clamp(_ range: ClosedRange<Self>) -> Self {
    max(range.lowerBound, min(range.upperBound, self))
  }
}

// TODO(dmt021): @_spi(Extensions)
extension Comparable where Self: Strideable, Self.Stride: SignedInteger {
  public func clamp(_ range: Range<Self>) -> Self? {
    guard !range.isEmpty else {
      return nil
    }
    return clamp(ClosedRange(range))
  }
}
