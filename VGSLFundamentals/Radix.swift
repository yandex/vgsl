// Copyright 2020 Yandex LLC. All rights reserved.

// radix must be in the range 2...36
public enum Radix: Int, Sendable {
  case decimal = 10
  case hex = 16
}

// TODO(dmt021): @_spi(Extensions)
extension FixedWidthInteger {
  @inlinable
  public init?(_ text: some StringProtocol, safeRadix radix: Radix) {
    // swiftlint:disable init_radix
    self.init(text, radix: radix.rawValue)
    // swiftlint:enable init_radix
  }
}

// TODO(dmt021): @_spi(Extensions)
extension String {
  @inlinable
  public init(_ value: some BinaryInteger, safeRadix radix: Radix, uppercase: Bool = false) {
    // swiftlint:disable init_radix
    self.init(value, radix: radix.rawValue, uppercase: uppercase)
    // swiftlint:enable init_radix
  }
}
