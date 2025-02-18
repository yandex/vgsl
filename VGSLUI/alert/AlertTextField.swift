// Copyright 2020 Yandex LLC. All rights reserved.

import Foundation

public struct AlertTextField: Equatable, Sendable {
  public enum ReturnKeyType: Sendable {
    case `default`
    case go
    case google
    case join
    case next
    case route
    case search
    case send
    case yahoo
    case done
    case emergencyCall
    case `continue`
  }

  public let placeholder: String?
  public let initialText: String?
  public let isSecureTextEntry: Bool
  public let enablesReturnKeyAutomatically: Bool
  public let returnKeyType: ReturnKeyType

  public init(
    placeholder: String? = nil,
    initialText: String? = nil,
    isSecureTextEntry: Bool = false,
    enablesReturnKeyAutomatically: Bool = false,
    returnKeyType: ReturnKeyType = .default
  ) {
    self.placeholder = placeholder
    self.initialText = initialText
    self.isSecureTextEntry = isSecureTextEntry
    self.enablesReturnKeyAutomatically = enablesReturnKeyAutomatically
    self.returnKeyType = returnKeyType
  }
}
