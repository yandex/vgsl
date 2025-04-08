// Copyright 2018 Yandex LLC. All rights reserved.

import Foundation

import VGSLFundamentals

public typealias ChallengeHandlers = (
  webViewChallengeHandler: ChallengeHandling,
  webContentChallengeHandler: ChallengeHandling?
)

public protocol ChallengeHandling {
  func handleChallenge(
    with protectionSpace: URLProtectionSpace,
    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
  )
}

private let _externalURLSessionChallengeHandler: AllocatedUnfairLock<ChallengeHandling?> =
  .init(sendingState: nil)
public var externalURLSessionChallengeHandler: ChallengeHandling? {
  get {
    _externalURLSessionChallengeHandler.withLockUnchecked { $0 }
  }
  set {
    _externalURLSessionChallengeHandler.withLockUnchecked { $0 = newValue }
  }
}
