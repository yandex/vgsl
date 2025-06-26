// Copyright 2022 Yandex LLC. All rights reserved.

internal import SwiftShims

public struct OSInfo: Sendable {
  public enum Platform: Equatable, Sendable {
    /// https://docs.swift.org/swift-book/ReferenceManual/Statements.html#ID539
    case macOS, iOS, watchOS, tvOS, linux, windows

    @inlinable
    public static var current: Self {
      #if os(macOS)
      .macOS
      #elseif os(iOS)
      .iOS
      #elseif os(watchOS)
      .watchOS
      #elseif os(tvOS)
      .tvOS
      #elseif os(Linux)
      .linux
      #elseif os(Windows)
      .windows
      #else
      #error("Unknown platform")
      #endif
    }
  }

  public var version: OSVersion
  public var platform: Platform

  @inlinable
  public init(
    version: OSVersion,
    platform: Platform
  ) {
    self.version = version
    self.platform = platform
  }

  static let _current = Self(
    version: operatingSystemVersion(),
    platform: Platform.current
  )

  static func operatingSystemVersion() -> OSVersion {
    let v = _swift_stdlib_operatingSystemVersion()
    return OSVersion(v.majorVersion, v.minorVersion, v.patchVersion)
  }

  private static let __current: AllocatedUnfairLock<Self> = .init(initialState: ._current)
  public static var current: Self {
    __current.withLock { $0 }
  }

  @_spi(Internal)
  public static func setCurrent(_ value: Self) {
    __current.withLock { $0 = value }
  }

  static func restoreSystemCurrent() {
    setCurrent(_current)
  }
}
