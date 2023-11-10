// Copyright 2022 Yandex LLC. All rights reserved.

public struct OSVersion: Comparable {
  public typealias Tuple2 = (Int, Int)
  public typealias Tuple3 = (Int, Int, Int)

  public var major: Int
  public var minor: Int
  public var patch: Int

  public init(tuple: Tuple2) {
    self.init(tuple.0, tuple.1)
  }

  public init(tuple: Tuple3) {
    self.init(tuple.0, tuple.1, tuple.2)
  }

  public init(_ major: Int) {
    self.init(major, 0)
  }

  public init(_ major: Int, _ minor: Int) {
    self.init(major, minor, 0)
  }

  public init(_ major: Int, _ minor: Int, _ patch: Int) {
    self.major = major
    self.minor = minor
    self.patch = patch
  }

  public static func <(lhs: Self, rhs: Self) -> Bool {
    (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
  }
}
