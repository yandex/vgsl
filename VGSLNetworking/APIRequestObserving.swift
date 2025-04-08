// Copyright 2019 Yandex LLC. All rights reserved.

import Foundation

@preconcurrency @MainActor
public protocol APIRequestObserving: Sendable {
  func requestWillBeSent(to url: URL, HTTPBody: Any?)
  func requestParsingWillStart()
  func requestParsingDidFail(error: Error, responseData: Data)
  func requestParsingDidEnd(responseData: Data)
  func requestDidFail(url: URL?, error: Error)
}

extension APIRequestObserving {
  public func requestDidFail(error: Error) {
    requestDidFail(url: nil, error: error)
  }
}

public typealias APIRequestObservingFactory = () -> APIRequestObserving
