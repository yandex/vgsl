// Copyright 2019 Yandex LLC. All rights reserved.

// TODO(dmt021): @_spi(Extensions)
extension UnsignedInteger where Self: FixedWidthInteger {
  /// Creates a new instance from the given integer, if it can be represented
  /// exactly. Otherwise `InvalidArgumentError` will be thrown.
  @inlinable
  public init(value: some BinaryInteger & Sendable) throws {
    guard let converted = Self(exactly: value) else {
      throw InvalidArgumentError(name: "value", value: value)
    }
    self = converted
  }
}
