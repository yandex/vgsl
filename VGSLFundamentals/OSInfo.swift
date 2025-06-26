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
    self = .init(_version: version, _platform: platform)
  }

  @usableFromInline
  internal init(_version: OSVersion, _platform: Platform) {
    self.version = _version
    self.platform = _platform
  }

  static let _current = Self(
    version: operatingSystemVersion(),
    platform: Platform.current
  )

  static func operatingSystemVersion() -> OSVersion {
    let v = _swift_stdlib_operatingSystemVersion()
    return OSVersion(v.majorVersion, v.minorVersion, v.patchVersion)
  }

  #if INTERNAL_BUILD
  private static let __current: AllocatedUnfairLock<Self> = .init(initialState: ._current)
  public static var current: Self {
    get {
      __current.withLock { $0 }
    }
    set {
      __current.withLock { $0 = newValue }
    }
  }

  static func restoreSystemCurrent() {
    current = _current
  }
  #else
  public static let current: Self = ._current
  #endif
}
