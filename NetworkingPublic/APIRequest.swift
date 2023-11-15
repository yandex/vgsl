// Copyright 2015 Yandex LLC. All rights reserved.

import Foundation

import BasePublic

public let APIRequestErrorDomain = "vgsl.commonCore.networking"
public let APIRequestResponseParsingErrorCode = 0

@inlinable
public func wrappedAPIRequest<T>(
  _ requestPerformer: URLRequestPerforming,
  parsingQueue: OperationQueueType,
  preRequestAction: (() -> Void)? = nil,
  observer: APIRequestObserving? = nil,
  networkActivityIndicator: NetworkActivityIndicatorController
) -> NetworkActivityOperation<T>.Request {
  {
    preRequestAction?()
    return APIRequest(
      requestPerformer: requestPerformer,
      parsingQueue: parsingQueue,
      baseURL: $0,
      resource: $1,
      networkActivityIndicator: networkActivityIndicator,
      downloadProgressHandler: $2,
      uploadProgressHandler: $3,
      observer: observer,
      completion: $4
    )
  }
}

#if !os(tvOS)
@inlinable
@available(iOSApplicationExtension, unavailable)
public func wrappedAPIRequest<T>(
  _ requestPerformer: URLRequestPerforming,
  parsingQueue: OperationQueueType,
  preRequestAction: (() -> Void)? = nil,
  observer: APIRequestObserving? = nil,
  customNetworkActivityIndicator: NetworkActivityIndicatorController? = nil
) -> NetworkActivityOperation<T>.Request {
  wrappedAPIRequest(
    requestPerformer,
    parsingQueue: parsingQueue,
    preRequestAction: preRequestAction,
    observer: observer,
    networkActivityIndicator: customNetworkActivityIndicator ?? networkActivityIndicatorController
  )
}
#endif

@inlinable
public func APIRequest<T>(
  requestPerformer: URLRequestPerforming,
  parsingQueue: OperationQueueType,
  baseURL: URL,
  resource: Resource<T>,
  networkActivityIndicator: NetworkActivityIndicatorController,
  downloadProgressHandler: ((Double) -> Void)? = nil,
  uploadProgressHandler: ((Double) -> Void)? = nil,
  observer: APIRequestObserving? = nil,
  completion: @escaping (Result<T, NSError>) -> Void
) -> NetworkTask {
  let request = URLRequestForResource(resource, withBaseURL: baseURL)

  var httpBody: Any?
  if let body = request.httpBody {
    httpBody = try? JSONSerialization.jsonObject(with: body, options: [])
  }

  onMainThread {
    observer?.requestWillBeSent(to: request.url!, HTTPBody: httpBody)
    networkActivityIndicator.incrementNumberOfOperations()
  }

  let responseHandler: URLRequestCompletionHandler = { result in
    Thread.assertIsMain()
    networkActivityIndicator.decrementNumberOfOperations()
    observer?.requestParsingWillStart()
    switch result {
    case let .success((data, response)):
      parsingQueue.addOperation {
        do {
          let result = try resource.parser(data, response)
          onMainThread {
            observer?.requestParsingDidEnd(responseData: data)
            completion(.success(result))
          }
        } catch {
          let parsingError = NSError(
            domain: APIRequestErrorDomain,
            code: APIRequestResponseParsingErrorCode,
            userInfo: [NSUnderlyingErrorKey: error]
          )

          onMainThread {
            observer?.requestParsingDidFail(error: parsingError, responseData: data)
            completion(.failure(parsingError))
          }
        }
      }
    case let .failure(error):
      observer?.requestDidFail(url: request.url, error: error)
      completion(.failure(error))
    }
  }
  return requestPerformer.performRequest(
    request,
    downloadProgressHandler: downloadProgressHandler,
    uploadProgressHandler: uploadProgressHandler,
    completion: responseHandler
  )
}

#if !os(tvOS)
@available(iOSApplicationExtension, unavailable)
@inlinable
public func APIRequest<T>(
  requestPerformer: URLRequestPerforming,
  parsingQueue: OperationQueueType,
  baseURL: URL,
  resource: Resource<T>,
  customNetworkActivityIndicator: NetworkActivityIndicatorController? = nil,
  downloadProgressHandler: ((Double) -> Void)? = nil,
  uploadProgressHandler: ((Double) -> Void)? = nil,
  observer: APIRequestObserving? = nil,
  completion: @escaping (Result<T, NSError>) -> Void
) -> NetworkTask {
  APIRequest(
    requestPerformer: requestPerformer,
    parsingQueue: parsingQueue,
    baseURL: baseURL,
    resource: resource,
    networkActivityIndicator: customNetworkActivityIndicator ?? networkActivityIndicatorController,
    downloadProgressHandler: downloadProgressHandler,
    uploadProgressHandler: uploadProgressHandler,
    observer: observer,
    completion: completion
  )
}
#endif
