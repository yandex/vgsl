// Copyright 2021 Yandex LLC. All rights reserved.

// TODO(dmt021): @_spi(Extensions)
extension FloatingPoint where Self.Stride: ExpressibleByFloatLiteral {
  public func isApproximatelyGreaterThan(
    _ number: Self,
    withAccuracy accuracy: Self.Stride
  ) -> Bool {
    number.distance(to: self) > accuracy
  }

  public func isApproximatelyGreaterThan(_ number: Self) -> Bool {
    isApproximatelyGreaterThan(number, withAccuracy: defaultAccuracy())
  }

  public func isApproximatelyGreaterOrEqualThan(
    _ number: Self,
    withAccuracy accuracy: Self.Stride
  ) -> Bool {
    !isApproximatelyLessThan(number, withAccuracy: accuracy)
  }

  public func isApproximatelyGreaterOrEqualThan(_ number: Self) -> Bool {
    !isApproximatelyLessThan(number, withAccuracy: defaultAccuracy())
  }

  public func isApproximatelyLessThan(_ number: Self, withAccuracy accuracy: Self.Stride) -> Bool {
    number.isApproximatelyGreaterThan(self, withAccuracy: accuracy)
  }

  public func isApproximatelyLessThan(_ number: Self) -> Bool {
    number.isApproximatelyGreaterThan(self, withAccuracy: defaultAccuracy())
  }

  public func isApproximatelyLessOrEqualThan(
    _ number: Self,
    withAccuracy accuracy: Self.Stride
  ) -> Bool {
    !isApproximatelyGreaterThan(number, withAccuracy: accuracy)
  }

  public func isApproximatelyLessOrEqualThan(_ number: Self) -> Bool {
    !isApproximatelyGreaterThan(number, withAccuracy: defaultAccuracy())
  }

  public func isApproximatelyEqualTo(_ number: Self, withAccuracy accuracy: Self.Stride) -> Bool {
    !isApproximatelyGreaterThan(number, withAccuracy: accuracy) &&
      !isApproximatelyLessThan(number, withAccuracy: accuracy)
  }

  public func isApproximatelyEqualTo(_ number: Self) -> Bool {
    !isApproximatelyGreaterThan(number, withAccuracy: defaultAccuracy()) &&
      !isApproximatelyLessThan(number, withAccuracy: defaultAccuracy())
  }

  public func isApproximatelyNotEqualTo(
    _ number: Self,
    withAccuracy accuracy: Self.Stride
  ) -> Bool {
    !isApproximatelyEqualTo(number, withAccuracy: accuracy)
  }

  public func isApproximatelyNotEqualTo(_ number: Self) -> Bool {
    !isApproximatelyEqualTo(number, withAccuracy: defaultAccuracy())
  }
}

// TODO(dmt021): @_spi(Extensions)
extension BinaryFloatingPoint {
  // https://github.com/apple/swift-evolution/blob/master/proposals/0259-approximately-equal.md
  @inlinable
  public func isAlmostEqual(
    _ other: Self,
    maxRelDev: Self = Self.ulpOfOne.squareRoot()
  ) -> Bool {
    precondition(maxRelDev >= Self.zero)
    precondition(isFinite && other.isFinite)
    guard self != other else { return true }
    guard !isZero else { return other.isAlmostZero() }
    guard !other.isZero else { return isAlmostZero() }
    let scale = max(abs(self), abs(other), .leastNormalMagnitude)
    return abs(self - other) < scale * maxRelDev
  }

  @inlinable
  public func isAlmostZero(
    absoluteTolerance tolerance: Self = Self.ulpOfOne.squareRoot()
  ) -> Bool {
    assert(tolerance > 0)
    return abs(self) < tolerance
  }
}

@inlinable
public func lerp<T: FloatingPoint>(at: T, beetween lhs: T, _ rhs: T) -> T {
  lhs + (rhs - lhs) * at
}

private func defaultAccuracy<Type: ExpressibleByFloatLiteral>() -> Type { 1e-8 }
