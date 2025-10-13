// Copyright 2021 Yandex LLC. All rights reserved.

import Foundation

extension Encodable {
  public func toJSONString(formatting: JSONEncoder.OutputFormatting? = nil) throws -> String {
    let data = try jsonData(formatting: formatting)
    return String(data: data, encoding: .utf8)!
  }

  public func jsonData(formatting: JSONEncoder.OutputFormatting? = nil) throws -> Data {
    let encoder = JSONEncoder()
    if let formatting {
      encoder.outputFormatting = formatting
    }
    return try encoder.encode(self)
  }
}
