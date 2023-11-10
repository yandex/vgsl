// Copyright 2021 Yandex LLC. All rights reserved.

import Foundation

extension String {
  public var containsOnlyWhitespace: Bool {
    trimmingCharacters(in: .whitespaces).isEmpty
  }

  public init(forQueryItemWithName name: String, value: String?) {
    let valueString = value.map { "=\($0.percentEncoded())" } ?? ""
    self = name.percentEncoded() + valueString
  }

  public func percentEncoded() -> String {
    addingPercentEncoding(withAllowedCharacters: URLUnreservedCharSet)!
  }

  public var percentEncodedURLString: String {
    let stringWithoutEncoding = removingPercentEncoding ?? self
    return stringWithoutEncoding.addingPercentEncoding(withAllowedCharacters: URLAllowedCharSet)!
  }

  public var percentEncodedExceptSpecialAndLatin: String {
    addingPercentEncoding(withAllowedCharacters: URLSpecialAndLatinCharSet)!
  }

  public func quoted() -> String {
    guard let jsString = try? JSONSerialization.data(
      withJSONObject: self,
      options: .fragmentsAllowed
    ),
      let result = String(data: jsString, encoding: .utf8) else {
      assertionFailure()
      return ""
    }
    return result
  }
}

// RFC 3986 section 2.2
private let URLReservedChars = "!*'();:@&=+$,/?#[]"
private let URLUnreservedChars =
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~"
private let URLSpecialAndLatinChars = URLReservedChars + URLUnreservedChars + "%"
private let URLUnreservedCharSet = CharacterSet(charactersIn: URLUnreservedChars)
private let URLAllowedCharSet = CharacterSet(charactersIn: URLReservedChars + URLUnreservedChars)
private let URLSpecialAndLatinCharSet = CharacterSet(charactersIn: URLSpecialAndLatinChars)
