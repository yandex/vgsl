// Copyright 2015 Yandex LLC. All rights reserved.

import Foundation

import VGSLFundamentals

public let URLSessionErrorResponseKey = "URLSessionErrorResponseKey"
public let URLSessionErrorReceivedDataKey = "URLSessionErrorReceivedDataKey"

private func isExpectedBytesCountToTransferValid(_ expectedBytesToTransfer: Int64) -> Bool {
  expectedBytesToTransfer != NSURLSessionTransferSizeUnknown && expectedBytesToTransfer != 0
}

@objc(YXURLSessionDelegateImpl)
@preconcurrency @MainActor
public final class URLSessionDelegateImpl: NSObject {
  public typealias ProgressChangeHandler = (Double) -> Void
  public typealias CompletionHandler = (Result<(Data, HTTPURLResponse), NSError>) -> Void
  public typealias RedirectHandler = (HTTPURLResponse, URLRequest) -> URLRequest

  private struct TaskState {
    let downloadProgressChangeHandler: ProgressChangeHandler?
    let uploadProgressChangeHandler: ProgressChangeHandler?
    let challengeHandler: ChallengeHandling?
    let redirectHandler: RedirectHandler?
    let completionHandler: CompletionHandler
    var receivedData: Data
  }

  private var stateByTask = [URLSessionTask: TaskState]()
  private var challengeHandler: ChallengeHandling?
  private let errorInferrer: (URLSessionTask, Error?, Data) -> NSError?

  public init(errorInferrer: @escaping (URLSessionTask, Error?, Data) -> NSError? = inferError) {
    self.errorInferrer = errorInferrer
  }

  @preconcurrency @MainActor
  public func setHandlers(
    downloadProgressChange: ProgressChangeHandler? = nil,
    uploadProgressChange: ProgressChangeHandler? = nil,
    challengeHandler: ChallengeHandling? = nil,
    redirectHandler: RedirectHandler? = nil,
    completion: @escaping CompletionHandler,
    forTask task: URLSessionDataTask
  ) {
    Thread.assertIsMain()
    assert(stateByTask[task] == nil && task.state == .suspended)
    stateByTask[task] = TaskState(
      downloadProgressChangeHandler: downloadProgressChange,
      uploadProgressChangeHandler: uploadProgressChange,
      challengeHandler: challengeHandler,
      redirectHandler: redirectHandler,
      completionHandler: completion,
      receivedData: Data()
    )
    self.challengeHandler = challengeHandler
  }
}

extension URLSessionDelegateImpl: URLSessionDataDelegate {
  public nonisolated func urlSession(
    _: URLSession,
    task: URLSessionTask,
    didSendBodyData _: Int64,
    totalBytesSent: Int64,
    totalBytesExpectedToSend: Int64
  ) {
    assumeIsolatedToMainActor {
      guard isExpectedBytesCountToTransferValid(totalBytesExpectedToSend),
            let handler = stateByTask[task]?.uploadProgressChangeHandler else { return }

      let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
      handler(progress)
    }
  }

  public nonisolated func urlSession(
    _: URLSession,
    dataTask: URLSessionDataTask,
    didReceive data: Data
  ) {
    assumeIsolatedToMainActor {
      assert(stateByTask[dataTask] != nil)
      stateByTask[dataTask]?.receivedData.append(data)

      guard isExpectedBytesCountToTransferValid(dataTask.countOfBytesExpectedToReceive),
            let handler = stateByTask[dataTask]?.downloadProgressChangeHandler else { return }

      let progress = Double(dataTask.countOfBytesReceived) /
        Double(dataTask.countOfBytesExpectedToReceive)
      handler(progress)
    }
  }

  public nonisolated func urlSession(
    _: URLSession,
    task: URLSessionTask,
    didCompleteWithError error: Error?
  ) {
    assumeIsolatedToMainActor {
      guard let taskState = stateByTask.removeValue(forKey: task) else {
        assertionFailure()
        return
      }
      let result: Result<(Data, HTTPURLResponse), NSError>
      if let error = errorInferrer(task, error, taskState.receivedData) {
        result = .failure(error)
      } else {
        let response = task.response as! HTTPURLResponse
        result = .success((taskState.receivedData, response))
      }
      taskState.completionHandler(result)
    }
  }

  func isStoringStateForTask(_ task: URLSessionTask) -> Bool {
    stateByTask[task] != nil
  }

  public nonisolated func urlSession(
    _: URLSession,
    didReceive challenge: URLAuthenticationChallenge,
    completionHandler: @escaping @Sendable (
      URLSession.AuthChallengeDisposition,
      URLCredential?
    ) -> Void
  ) {
    onMainThread { [weak self] in
      guard let challengeHandler = self?.challengeHandler else {
        return completionHandler(.performDefaultHandling, nil)
      }
      challengeHandler.handleChallenge(
        with: challenge.protectionSpace,
        completionHandler: completionHandler
      )
    }
  }
}

extension URLSessionDelegateImpl: URLSessionTaskDelegate {
  public nonisolated func urlSession(
    _: URLSession,
    task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest,
    completionHandler: @escaping @Sendable (URLRequest?) -> Void
  ) {
    assumeIsolatedToMainActor {
      guard let redirectHandler = stateByTask[task]?.redirectHandler else {
        return completionHandler(request)
      }
      completionHandler(redirectHandler(response, request))
    }
  }
}

public func inferError(
  fromTask task: URLSessionTask,
  sessionError: Error?,
  receivedData: Data
) -> NSError? {
  var error: NSError?
  if let sessionError = sessionError as NSError? {
    error = sessionError
    if let response = task.response as? HTTPURLResponse {
      error = error?.byExtendingUserInfoWith(userInfo: [
        URLSessionErrorResponseKey: response,
      ])
    }
  } else {
    error = task.httpResponseError
  }

  return error?.byExtendingUserInfoWith(userInfo: [
    URLSessionErrorReceivedDataKey: receivedData,
  ])
}

extension NSError {
  fileprivate func byExtendingUserInfoWith(userInfo newUserInfo: [String: Any]) -> NSError {
    let extendedUserInfo = userInfo.merging(newUserInfo, uniquingKeysWith: { $1 })
    return NSError(domain: domain, code: code, userInfo: extendedUserInfo)
  }
}
