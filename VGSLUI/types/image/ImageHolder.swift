// Copyright 2018 Yandex LLC. All rights reserved.

import Foundation

import VGSLFundamentals

public protocol ImageHolder: AnyObject, CustomDebugStringConvertible {
  typealias CompletionHandlerWithSource = ((Image, URLRequestResult.Source)?) -> Void

  var image: Image? { get }
  var placeholder: ImagePlaceholder? { get }
  @discardableResult
  func requestImageWithCompletion(_ completion: @escaping ((Image?) -> Void)) -> Cancellable?
  func requestImageWithSource(_ completion: @escaping CompletionHandlerWithSource) -> Cancellable?
  func reused(with placeholder: ImagePlaceholder?, remoteImageURL: URL?) -> ImageHolder?
  func equals(_ other: ImageHolder) -> Bool
}

extension ImageHolder {
  public func requestImageWithSource(_ completion: @escaping CompletionHandlerWithSource)
    -> Cancellable? {
    requestImageWithCompletion {
      if let image = $0 {
        completion((image, .network))
      } else {
        completion(nil)
      }
    }
  }
}

public func compare(_ lhs: ImageHolder, _ rhs: ImageHolder) -> Bool {
  if lhs === rhs {
    return true
  }

  return lhs.equals(rhs)
}

public func compare(_ lhs: ImageHolder?, _ rhs: ImageHolder?) -> Bool {
  switch (lhs, rhs) {
  case (.none, .none):
    true
  case let (.some(value1), .some(value2)):
    compare(value1, value2)
  default:
    false
  }
}
