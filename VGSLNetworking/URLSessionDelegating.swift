// Copyright 2015 Yandex LLC. All rights reserved.

import Foundation

import VGSLFundamentals

/// Protocol that defines the interface for URL session delegate implementations.
/// Allows for custom delegate implementations to be passed to URLRequestPerformer.
///
/// Note: Implementations can choose their own actor isolation strategy.
/// For example, `URLSessionDelegateImpl` uses `@MainActor` isolation.
@preconcurrency
public protocol NetworkingDelegate: URLSessionDataDelegate, URLSessionTaskDelegate {
  typealias ProgressChangeHandler = (Double) -> Void
  typealias CompletionHandler = (Result<(Data, HTTPURLResponse), NSError>) -> Void
  typealias RedirectHandler = (HTTPURLResponse, URLRequest) -> URLRequest

  /// Sets handlers for a specific URL session task.
  ///
  /// - Parameters:
  ///   - downloadProgressChange: Optional handler for download progress updates.
  ///   - uploadProgressChange: Optional handler for upload progress updates.
  ///   - challengeHandler: Optional handler for authentication challenges.
  ///   - redirectHandler: Optional handler for HTTP redirects.
  ///   - completion: Completion handler that will be called when the task finishes.
  ///   - task: The URL session data task for which to set the handlers.
  func setHandlers(
    downloadProgressChange: ProgressChangeHandler?,
    uploadProgressChange: ProgressChangeHandler?,
    challengeHandler: ChallengeHandling?,
    redirectHandler: RedirectHandler?,
    completion: @escaping CompletionHandler,
    forTask task: URLSessionDataTask
  )
}

