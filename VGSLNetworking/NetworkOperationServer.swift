// Copyright 2016 Yandex LLC. All rights reserved.

import Foundation

import VGSLFundamentals

@preconcurrency @MainActor
public protocol NetworkOperationServing: AnyObject {
  associatedtype RequestArgs
  associatedtype Response

  @discardableResult
  func performRequest(
    _ args: RequestArgs,
    completion: NetworkActivityOperation<Response>.Completion?
  ) -> Operation

  func cancel()
}

public final class NetworkOperationServer<RequestArgs, Response>: NetworkOperationServing {
  public typealias NetworkOperation = NetworkActivityOperation<Response>
  public typealias Completion = NetworkOperation.Completion
  public typealias OperationFactory = (_ args: RequestArgs, _ completion: @escaping Completion)
    -> NetworkOperation
  private let operationFactory: OperationFactory
  private let dependencies: [Operation]
  private let operationQueue: OperationQueueType
  private let shouldCancelCurrentOperation: Bool
  private var currentOperation: NetworkOperation?

  public init(
    operationFactory: @escaping OperationFactory,
    dependencies: [Operation] = [],
    operationQueue: OperationQueueType,
    shouldCancelCurrentOperation: Bool = true
  ) {
    self.operationFactory = operationFactory
    self.dependencies = dependencies
    assert(operationQueue !== MainQueue)
    self.operationQueue = operationQueue
    self.shouldCancelCurrentOperation = shouldCancelCurrentOperation
  }

  @discardableResult
  public func performRequest(_ args: RequestArgs, completion: Completion? = nil) -> Operation {
    precondition(Thread.isMainThread)
    if shouldCancelCurrentOperation {
      currentOperation?.cancel()
    }
    let op = operationFactory(args) { completion?($0) }
    dependencies.forEach(op.addDependency)
    currentOperation = op
    operationQueue.addOperation(op)
    return op
  }

  public func cancel() {
    currentOperation?.cancel()
  }
}

extension NetworkOperationServing where RequestArgs == Void {
  public func performRequest(_ completion: NetworkActivityOperation<Response>.Completion? = nil) {
    performRequest((), completion: completion)
  }
}

extension NetworkOperationServing {
  @available(iOS 13, tvOS 13, *)
  @discardableResult
  @MainActor
  public func performRequest(_ args: RequestArgs) async throws -> Response {
    try await withCheckedThrowingContinuation { continuation in
      nonisolated(unsafe) var receivedResult: Result<Response, NSError>?
      let serverOp = performRequest(args, completion: { result in
        receivedResult = result
      })
      let continuationOp = BlockOperation {
        MainActor.assumeIsolated {
          if let receivedResult {
            nonisolated(unsafe) let receivedResult = receivedResult
            continuation.resume(with: receivedResult)
          } else {
            continuation.resume(throwing: CancellationError())
          }
        }
      }
      continuationOp.addDependency(serverOp)
      OperationQueue.main.addOperation(continuationOp)
    }
  }
}

extension NetworkOperationServer {
  public convenience init(
    baseURL: Variable<URL>,
    resourceFactory: @escaping (RequestArgs) -> Resource<Response>?,
    requestPerformer: URLRequestPerforming,
    parsingQueue: OperationQueueType,
    preRequestAction: (() -> Void)? = nil,
    observer: APIRequestObserving? = nil,
    userAgent: Variable<String?>,
    errorStrategyFactory: NetworkErrorHandlingStrategyFactory? = nil,
    dependencies: [Operation] = [],
    operationQueue: OperationQueueType,
    shouldCancelCurrentOperation: Bool = true,
    networkActivityIndicator: NetworkActivityIndicatorController,
    activityOperationModifier: ((NetworkOperation) -> NetworkOperation)? = nil
  ) {
    let operationFactory: NetworkOperationServer.OperationFactory = { args, completion in
      let errorStrategy = errorStrategyFactory?()
      let operation = NetworkActivityOperation(
        baseURLProvider: baseURL,
        resourceFactory: Variable { resourceFactory(args) },
        request: wrappedAPIRequest(
          requestPerformer,
          parsingQueue: parsingQueue,
          preRequestAction: preRequestAction,
          observer: observer,
          networkActivityIndicator: networkActivityIndicator
        ),
        userAgent: userAgent,
        errorStrategy: errorStrategy,
        completion: completion
      )
      return activityOperationModifier?(operation) ?? operation
    }
    self.init(
      operationFactory: operationFactory,
      dependencies: dependencies,
      operationQueue: operationQueue,
      shouldCancelCurrentOperation: shouldCancelCurrentOperation
    )
  }

  public convenience init(
    baseURL: Variable<URL>,
    resourceFactory: @escaping (RequestArgs) -> Resource<Response>?,
    requestPerformer: URLRequestPerforming,
    parsingQueue: OperationQueueType,
    preRequestAction: (() -> Void)? = nil,
    observer: APIRequestObserving? = nil,
    userAgent: String,
    errorStrategyFactory: NetworkErrorHandlingStrategyFactory? = nil,
    dependencies: [Operation] = [],
    operationQueue: OperationQueueType,
    shouldCancelCurrentOperation: Bool = true,
    networkActivityIndicator: NetworkActivityIndicatorController,
    activityOperationModifier: ((NetworkOperation) -> NetworkOperation)? = nil
  ) {
    self.init(
      baseURL: baseURL,
      resourceFactory: resourceFactory,
      requestPerformer: requestPerformer,
      parsingQueue: parsingQueue,
      preRequestAction: preRequestAction,
      observer: observer,
      userAgent: .constant(userAgent),
      errorStrategyFactory: errorStrategyFactory,
      dependencies: dependencies,
      operationQueue: operationQueue,
      shouldCancelCurrentOperation: shouldCancelCurrentOperation,
      networkActivityIndicator: networkActivityIndicator,
      activityOperationModifier: activityOperationModifier
    )
  }

  #if !os(tvOS)
  @available(iOSApplicationExtension, unavailable)
  public convenience init(
    baseURL: Variable<URL>,
    resourceFactory: @escaping (RequestArgs) -> Resource<Response>?,
    requestPerformer: URLRequestPerforming,
    parsingQueue: OperationQueueType,
    preRequestAction: (() -> Void)? = nil,
    observer: APIRequestObserving? = nil,
    userAgent: Variable<String?>,
    errorStrategyFactory: NetworkErrorHandlingStrategyFactory? = nil,
    dependencies: [Operation] = [],
    operationQueue: OperationQueueType,
    shouldCancelCurrentOperation: Bool = true,
    customNetworkActivityIndicator: NetworkActivityIndicatorController? = nil,
    activityOperationModifier: ((NetworkOperation) -> NetworkOperation)? = nil
  ) {
    self.init(
      baseURL: baseURL,
      resourceFactory: resourceFactory,
      requestPerformer: requestPerformer,
      parsingQueue: parsingQueue,
      preRequestAction: preRequestAction,
      observer: observer,
      userAgent: userAgent,
      errorStrategyFactory: errorStrategyFactory,
      dependencies: dependencies,
      operationQueue: operationQueue,
      shouldCancelCurrentOperation: shouldCancelCurrentOperation,
      networkActivityIndicator: customNetworkActivityIndicator ??
        networkActivityIndicatorController,
      activityOperationModifier: activityOperationModifier
    )
  }

  @available(iOSApplicationExtension, unavailable)
  public convenience init(
    baseURL: Variable<URL>,
    resourceFactory: @escaping (RequestArgs) -> Resource<Response>?,
    requestPerformer: URLRequestPerforming,
    parsingQueue: OperationQueueType,
    preRequestAction: (() -> Void)? = nil,
    observer: APIRequestObserving? = nil,
    userAgent: String,
    errorStrategyFactory: NetworkErrorHandlingStrategyFactory? = nil,
    dependencies: [Operation] = [],
    operationQueue: OperationQueueType,
    shouldCancelCurrentOperation: Bool = true,
    customNetworkActivityIndicator: NetworkActivityIndicatorController? = nil,
    activityOperationModifier: ((NetworkOperation) -> NetworkOperation)? = nil
  ) {
    self.init(
      baseURL: baseURL,
      resourceFactory: resourceFactory,
      requestPerformer: requestPerformer,
      parsingQueue: parsingQueue,
      preRequestAction: preRequestAction,
      observer: observer,
      userAgent: .constant(userAgent),
      errorStrategyFactory: errorStrategyFactory,
      dependencies: dependencies,
      operationQueue: operationQueue,
      shouldCancelCurrentOperation: shouldCancelCurrentOperation,
      networkActivityIndicator: customNetworkActivityIndicator ??
        networkActivityIndicatorController,
      activityOperationModifier: activityOperationModifier
    )
  }
  #endif
}
