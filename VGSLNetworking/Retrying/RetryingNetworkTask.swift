// Copyright 2018 Yandex LLC. All rights reserved.

import Foundation

import VGSLFundamentals

public final class RetryingNetworkTask: NetworkTask, NetworkErrorHandlingStrategyDelegate {
  public var taskDescription: String? {
    get {
      currentTask.taskDescription
    }
    set {
      currentTask.taskDescription = newValue
    }
  }

  private(set) var currentTask: URLSessionDataTask
  private let dataTaskFactory: (URLRequest) -> URLSessionDataTask
  let request: URLRequest

  private let retryStrategy: NetworkErrorHandlingStrategy
  private let retryAction: (RetryingNetworkTask) -> Void
  private var retainSelf: RetryingNetworkTask?

  private let queue = DispatchQueue(label: "com.retryingNetworkTask.queue")

  public init(
    request: URLRequest,
    dataTaskFactory: @escaping (URLRequest) -> URLSessionDataTask,
    retryStrategy: NetworkErrorHandlingStrategy,
    retryAction: @escaping (RetryingNetworkTask) -> Void
  ) {
    self.request = request
    self.dataTaskFactory = dataTaskFactory
    self.currentTask = dataTaskFactory(request)
    self.retryStrategy = retryStrategy
    self.retryAction = retryAction
    retryStrategy.delegate = self
    retainSelf = self
  }

  public func resume() {
    currentTask.resume()
  }

  public nonisolated func cancel() {
    queue.async { [self] in
      currentTask.cancel()
      retryStrategy.delegate = nil
      retainSelf = nil
    }
  }

  func onSuccess() {
    cancel()
  }

  func handleError(_ error: NSError) -> NetworkErrorHandlingPolicy {
    let policy = retryStrategy.policy(for: error, from: request.url!)
    if policy != .waitForRetry {
      cancel()
    }
    return policy
  }

  public nonisolated func performRetry() {
    queue.async { [self] in
      currentTask = dataTaskFactory(request)
      retryAction(self)
    }
  }
}
