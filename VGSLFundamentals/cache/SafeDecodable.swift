// Copyright 2018 Yandex LLC. All rights reserved.

import Foundation

public struct SafeDecodable<Base: Decodable>: Decodable {
  public let value: Base?

  public init(from decoder: Decoder) throws {
    do {
      let container = try decoder.singleValueContainer()
      self.value = try container.decode(Base.self)
    } catch {
      assertionFailure("Decoding error: \(error)")
      self.value = nil
    }
  }
}

extension SafeDecodable: Sendable where Base: Sendable {}
