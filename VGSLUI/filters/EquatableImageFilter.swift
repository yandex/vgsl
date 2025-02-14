// Copyright 2024 Yandex LLC. All rights reserved.

import CoreImage

public protocol EquatableImageFilter: Equatable, Sendable {
  func apply(to image: CIImage) -> CIImage?
  var showOriginalImageIfFailed: Bool { get }
}

public struct AnyEquatableImageFilter: Sendable {
  public let value: any EquatableImageFilter
  private let equals: @Sendable (Any) -> Bool

  public init<T: EquatableImageFilter>(_ value: T) {
    self.value = value
    self.equals = { ($0 as? T == value) }
  }
}

extension AnyEquatableImageFilter: Equatable {
  public static func ==(lhs: AnyEquatableImageFilter, rhs: AnyEquatableImageFilter) -> Bool {
    lhs.equals(rhs.value)
  }
}
