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
  public typealias ProgressHandler = @MainActor (Double) -> Void
  public typealias Completion = @MainActor (sending Result<Response, NSError>) -> Void

  @MainActor
  private let baseURLProvider: Variable<URL>
  @MainActor
  private let resourceFactory: ResourceFutureFactory
  private let request: Request
  @MainActor
  private let userAgent: Variable<String?>
  private let downloadProgress: ProgressHandler?
  private let uploadProgress: ProgressHandler?
  @MainActor
  private var wasCancelled = false

  // public for tests
  @MainActor
  public let errorStrategy: NetworkErrorHandlingStrategy?

  @preconcurrency @MainActor
  public private(set) var result: Result<Response, NSError>?

  public let completion: Completion

  @MainActor
  private var networkTask: NetworkTask!

  @preconcurrency @MainActor
  public weak var lifecycleDelegate: NetworkActivityOperationLifecycleDelegate?

  @preconcurrency @MainActor
  @_spi(Internal) public var predefinedResponse: (body: Data, httpResponse: HTTPURLResponse)?

  @preconcurrency @MainActor
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

  @preconcurrency @MainActor
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
    assumeIsolatedToMainActor {
      wasCancelled = true
      networkTask?.cancel()
    }
    super.cancel()
  }

  @MainActor
  private func performRequest() {
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

  @MainActor
  private func performRequest(originalResource: Resource<Response>?) {
    guard let originalResource else {
      let error = NSError(
        domain: NetworkActivityOperationErrorDomain,
        code: NetworkActivityOperationErrorCode.failedToCreateResource.rawValue,
        userInfo: nil
      )
      completeWith(.failure(error))
      return
    }

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

  @MainActor
  private func handleRequestResult(_ result: Result<Response, NSError>, baseURL: URL) {
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

  @MainActor
  private func completeWith(_ result: sending Result<Response, NSError>) {
    defer { complete() }
    guard !wasCancelled else { return }
    self.result = result
    completion(result)
  }
}

extension NetworkActivityOperation: NetworkErrorHandlingStrategyDelegate {
  public func performRetry() {
    onMainThread { [self] in
      lifecycleDelegate?.onRetry()
      performRequest()
    }
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
