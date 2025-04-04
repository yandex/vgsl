// Copyright 2016 Yandex LLC. All rights reserved.

import Foundation

import VGSLFundamentals

public protocol NetworkTask: AnyObject, Cancellable {
  var taskDescription: String? { get set }
  func resume()
}

extension Foundation.URLSessionTask: VGSLNetworking.NetworkTask {}

public typealias URLRequestCompletionHandler = (Result<(Data, HTTPURLResponse), NSError>) -> Void

public protocol URLRequestPerforming: AnyObject {
  @discardableResult
  func performRequest(_ request: URLRequest, completion: @escaping URLRequestCompletionHandler)
    -> NetworkTask
  @discardableResult
  func performRequest(
    _ request: URLRequest,
    downloadProgressHandler: ((Double) -> Void)?,
    completion: @escaping URLRequestCompletionHandler
  ) -> NetworkTask
  @discardableResult
  func performRequest(
    _ request: URLRequest,
    downloadProgressHandler: ((Double) -> Void)?,
    uploadProgressHandler: ((Double) -> Void)?,
    completion: @escaping URLRequestCompletionHandler
  ) -> NetworkTask
}

extension URLRequestPerforming {
  public func performRequest(
    _ request: URLRequest,
    completion: @escaping URLRequestCompletionHandler
  ) -> NetworkTask {
    performRequest(
      request,
      downloadProgressHandler: nil,
      uploadProgressHandler: nil,
      completion: completion
    )
  }

  public func performRequest(
    _ request: URLRequest,
    downloadProgressHandler: ((Double) -> Void)?,
    completion: @escaping URLRequestCompletionHandler
  ) -> NetworkTask {
    performRequest(
      request,
      downloadProgressHandler: downloadProgressHandler,
      uploadProgressHandler: nil,
      completion: completion
    )
  }
}
