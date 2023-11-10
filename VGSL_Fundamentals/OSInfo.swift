// Copyright 2022 Yandex LLC. All rights reserved.

@_implementationOnly import SwiftShims

public struct OSInfo {
  public enum Platform: Equatable {
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

  @usableFromInline
  static let _current = Self(
    version: operatingSystemVersion(),
    platform: Platform.current
  )

  @inlinable
  static func operatingSystemVersion() -> OSVersion {
    let v = _swift_stdlib_operatingSystemVersion()
    return OSVersion(v.majorVersion, v.minorVersion, v.patchVersion)
  }

  #if INTERNAL_BUILD
  public static var current: Self = ._current

  static func restoreSystemCurrent() {
    current = _current
  }
  #else
  public static let current: Self = ._current
  #endif
}
