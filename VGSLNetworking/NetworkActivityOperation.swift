// Copyright 2015 Yandex LLC. All rights reserved.

import Foundation

import VGSLFundamentals

public let NetworkActivityOperationErrorDomain =
  "vgsl.commonCore.networking.NetworkActivityOperation"
public enum NetworkActivityOperationErrorCode: Int {
  case failedToCreateResource
  case cancelled
}

public final class NetworkActivityOperation<Response>: AsyncOperation, @unchecked Sendable {
  public typealias ResourceFactory = Variable<Resource<Response>?>
  public typealias ResourceFutureFactory = Variable<Future<Resource<Response>>?>
  public typealias Request = (
    URL,
    Resource<Response>,
    _ downloadProgress: ProgressHandler?,
    _ uploadProgress: ProgressHandler?,
    @escaping Completion
  ) -> NetworkTask
  public typealias ProgressHandler = (Double) -> Void
  public typealias Completion = (Result<Response, NSError>) -> Void

  private let baseURLProvider: Variable<URL>
  private let resourceFactory: ResourceFutureFactory
  private let request: Request
  private let userAgent: Variable<String?>
  private let downloadProgress: ProgressHandler?
  private let uploadProgress: ProgressHandler?
  private var wasCancelled = false

  // public for tests
  public let errorStrategy: NetworkErrorHandlingStrategy?

  public private(set) var result: Result<Response, NSError>?

  public let completion: Completion

  private var networkTask: NetworkTask!

  public weak var lifecycleDelegate: NetworkActivityOperationLifecycleDelegate?

  #if INTERNAL_BUILD
  public var predefinedResponse: (body: Data, httpResponse: HTTPURLResponse)?
  #endif

  public convenience init(
    baseURLProvider: Variable<URL>,
    resourceFactory: ResourceFactory,
    request: @escaping Request,
    userAgent: Variable<String?>,
    downloadProgress: ProgressHandler? = nil,
    uploadProgress: ProgressHandler? = nil,
    errorStrategy: NetworkErrorHandlingStrategy? = nil,
    completion: @escaping Completion
  ) {
    self.init(
      baseURLProvider: baseURLProvider,
      resourceFactory: Variable {
        resourceFactory.value.map { .resolved($0) }
      },
      request: request,
      userAgent: userAgent,
      downloadProgress: downloadProgress,
      uploadProgress: uploadProgress,
      errorStrategy: errorStrategy,
      completion: completion
    )
  }

  public init(
    baseURLProvider: Variable<URL>,
    resourceFactory: ResourceFutureFactory,
    request: @escaping Request,
    userAgent: Variable<String?>,
    downloadProgress: ProgressHandler? = nil,
    uploadProgress: ProgressHandler? = nil,
    errorStrategy: NetworkErrorHandlingStrategy? = nil,
    completion: @escaping Completion
  ) {
    self.baseURLProvider = baseURLProvider
    self.resourceFactory = resourceFactory
    self.request = request
    self.userAgent = userAgent
    self.downloadProgress = downloadProgress
    self.uploadProgress = uploadProgress
    self.errorStrategy = errorStrategy
    self.completion = completion

    super.init()

    errorStrategy?.delegate = self
  }

  public override func doStart() {
    onMainThread {
      self.performRequest()
    }
  }

  public override func cancel() {
    // MOBYANDEXIOS-813: Cancellation must happen on main thread to avoid races since cancellation flag is checked on
    // main thread as well

    wasCancelled = true
    networkTask?.cancel()
    precondition(Thread.isMainThread)
    super.cancel()
  }

  private func performRequest() {
    Thread.assertIsMain()
    guard let resource = resourceFactory.value else {
      return performRequest(originalResource: nil)
    }
    resource.resolved { resource in
      onMainThread { [self] in
        guard !isCancelled else {
          return completeWith(.failure(NSError(
            domain: NetworkActivityOperationErrorDomain,
            code: NetworkActivityOperationErrorCode.cancelled.rawValue,
            userInfo: nil
          )))
        }
        performRequest(originalResource: resource)
      }
    }
  }

  private func performRequest(originalResource: Resource<Response>?) {
    Thread.assertIsMain()
    guard let originalResource else {
      let error = NSError(
        domain: NetworkActivityOperationErrorDomain,
        code: NetworkActivityOperationErrorCode.failedToCreateResource.rawValue,
        userInfo: nil
      )
      completeWith(.failure(error))
      return
    }

    #if INTERNAL_BUILD
    if let response = predefinedResponse {
      after(0.5, onQueue: .global()) {
        let result = Result<Response, NSError>
          .success(try! originalResource.parser(response.body, response.httpResponse))
        onMainThread {
          self.completeWith(result)
        }
      }
      return
    }
    #endif

    precondition(originalResource.headers?[userAgentHeaderName] == nil)
    let resourceWithUserAgent = originalResource.mergedWithHeaders(
      HTTPHeaders(headersDictionary: [userAgentHeaderName: userAgent.value].filteringNilValues())
    )

    let baseURL = baseURLProvider.value
    networkTask = request(
      baseURL,
      resourceWithUserAgent,
      downloadProgress,
      uploadProgress
    ) { [weak self] in self?.handleRequestResult($0, baseURL: baseURL) }
  }

  private func handleRequestResult(_ result: Result<Response, NSError>, baseURL: URL) {
    Thread.assertIsMain()
    switch result {
    case .success:
      completeWith(result)
    case let .failure(error):
      let policy = errorStrategy?.policy(for: error, from: baseURL)
      if policy != .waitForRetry {
        completeWith(result)
      }
    }
  }

  private func completeWith(_ result: Result<Response, NSError>) {
    Thread.assertIsMain()
    defer { complete() }
    guard !wasCancelled else { return }
    self.result = result
    completion(result)
  }
}

extension NetworkActivityOperation: NetworkErrorHandlingStrategyDelegate {
  public func performRetry() {
    lifecycleDelegate?.onRetry()
    performRequest()
  }
}

extension NetworkActivityOperation: Cancellable {}

extension Resource {
  public func mergedWithHeaders(_ headers: HTTPHeaders) -> Resource {
    Resource(
      path: path,
      method: method,
      GETParameters: GETParameters,
      headers: (self.headers ?? HTTPHeaders.empty) + headers,
      body: body,
      parser: parser
    )
  }
}

private let userAgentHeaderName = "User-Agent"
