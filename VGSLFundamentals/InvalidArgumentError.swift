// Copyright 2019 Yandex LLC. All rights reserved.

import Foundation

public struct InvalidArgumentError: Error {
  public let name: String
  public let value: any Sendable

  #if DEBUG
  public let callStack = Thread.callStackSymbols
  #endif
  public init(name: String, value: any Sendable) {
    self.name = name
    self.value = value
  }
}
