// Copyright 2022 Yandex LLC. All rights reserved.

#if canImport(UIKit)
import UIKit

public struct AnchoredPoint {
  private let value: CGPoint
  private let space: UICoordinateSpace

  public init(value: CGPoint, space: UICoordinateSpace) {
    self.value = value
    self.space = space
  }

  @preconcurrency @MainActor
  public func coordinates(in other: UICoordinateSpace) -> CGPoint {
    other.convert(value, from: space)
  }
}
#endif
