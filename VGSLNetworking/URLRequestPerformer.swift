// Copyright 2017 Yandex LLC. All rights reserved.

import Foundation

import VGSLFundamentals

public final class URLRequestPerformer: URLRequestPerforming {
  public enum ChallengeHandler {
    case preferred(ChallengeHandling)
    case fallback(ChallengeHandling)
  }

  private let urlSession: URLSession
  private let URLSessionDelegate: any NetworkingDelegate
  private let activeRequestsTracker: ActiveRequestsTracker?
  private let challengeHandler: ChallengeHandler?
  private let redirectHandler: ((HTTPURLResponse, URLRequest) -> URLRequest)?
  private let trustedHosts: [String]
  private let urlTransform: URLTransform?

  /// Used for preventing memory leak when we are creating `URLSession` in `URLRequestPerformer`.
  /// Set to `true` if you are creating a `URLSession` in `URLRequestPerformer`, otherwise `false`.
  private let urlSessionShouldBeInvalidated: Bool

  private init(
    urlSession: URLSession,
    URLSessionDelegate: any NetworkingDelegate,
    activeRequestsTracker: ActiveRequestsTracker? = nil,
    challengeHandler: ChallengeHandler? = nil,
    redirectHandler: ((HTTPURLResponse, URLRequest) -> URLRequest)? = nil,
    trustedHosts: [String],
    urlTransform: URLTransform?,
    urlSessionShouldBeInvalidated: Bool
  ) {
    self.urlSession = urlSession
    self.URLSessionDelegate = URLSessionDelegate
    self.activeRequestsTracker = activeRequestsTracker
    self.challengeHandler = challengeHandler
    self.redirectHandler = redirectHandler
    self.trustedHosts = trustedHosts
    self.urlTransform = urlTransform
    self.urlSessionShouldBeInvalidated = urlSessionShouldBeInvalidated
  }

  public convenience init(
    urlSession: URLSession,
    URLSessionDelegate: any NetworkingDelegate,
    activeRequestsTracker: ActiveRequestsTracker? = nil,
    challengeHandler: ChallengeHandler? = nil,
    redirectHandler: ((HTTPURLResponse, URLRequest) -> URLRequest)? = nil,
    urlTransform: URLTransform?
  ) {
    self.init(
      urlSession: urlSession,
      URLSessionDelegate: URLSessionDelegate,
      activeRequestsTracker: activeRequestsTracker,
      challengeHandler: challengeHandler,
      redirectHandler: redirectHandler,
      trustedHosts: [],
      urlTransform: urlTransform,
      urlSessionShouldBeInvalidated: false
    )
  }

  public convenience init(
    urlTransform: URLTransform?,
    redirectHandler: ((HTTPURLResponse, URLRequest) -> URLRequest)? = nil,
    delegate: URLSessionDelegateImpl = URLSessionDelegateImpl()
  ) {
    let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: .main)
    self.init(
      urlSession: session,
      URLSessionDelegate: delegate,
      redirectHandler: redirectHandler,
      trustedHosts: [],
      urlTransform: urlTransform,
      urlSessionShouldBeInvalidated: true
    )
  }

  @_spi(Internal)
  public convenience init(trustedHosts: [String], urlTransform: URLTransform?) {
    let delegate = URLSessionDelegateImpl()
    let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: .main)
    self.init(
      urlSession: session,
      URLSessionDelegate: delegate,
      trustedHosts: trustedHosts,
      urlTransform: urlTransform,
      urlSessionShouldBeInvalidated: true
    )
  }

  deinit {
    if urlSessionShouldBeInvalidated {
      urlSession.finishTasksAndInvalidate()
    }
  }

  public func performRequest(
    _ request: URLRequest,
    downloadProgressHandler: ((Double) -> Void)?,
    uploadProgressHandler: ((Double) -> Void)?,
    completion: @escaping URLRequestCompletionHandler
  ) -> NetworkTask {
    let request = modified(request) { $0.url = urlTransform?($0.url) ?? $0.url }

    let task = urlSession.dataTask(with: request)

    onMainThread { [activeRequestsTracker] in
      activeRequestsTracker?.addRequest(request)
    }

    let delegateCompletion: URLRequestCompletionHandler = { [activeRequestsTracker] result in
      Thread.assertIsMain()
      completion(result)
      activeRequestsTracker?.removeRequest(request)
    }
    URLSessionDelegate.setHandlers(
      downloadProgressChange: downloadProgressHandler,
      uploadProgressChange: uploadProgressHandler,
      challengeHandler: makeChallengeHandler(
        challengeHandler: challengeHandler,
        trustedHosts: trustedHosts,
        request: request
      ),
      redirectHandler: redirectHandler,
      completion: delegateCompletion,
      forTask: task
    )
    task.resume()
    return task
  }
}

extension URLRequestPerformer.ChallengeHandler? {
  public var preferredChallengeHandler: ChallengeHandling? {
    guard let self else { return externalURLSessionChallengeHandler }

    switch self {
    case let .preferred(challengeHandler): return challengeHandler
    case let .fallback(challengeHandler):
      return externalURLSessionChallengeHandler ?? challengeHandler
    }
  }
}

private func makeChallengeHandler(
  challengeHandler: URLRequestPerformer.ChallengeHandler?,
  trustedHosts: [String],
  request: URLRequest
) -> ChallengeHandling {
  AuthChallengeHandler(
    nextHandler: challengeHandler.preferredChallengeHandler,
    trustedHosts: trustedHosts,
    request: request
  )
}
