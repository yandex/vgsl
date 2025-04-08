// Copyright 2019 Yandex LLC. All rights reserved.

import VGSLFundamentals

@preconcurrency @MainActor
public final class AsyncResourceRequester<Resource> {
  public typealias Completion = @MainActor (Resource?) -> Void
  public typealias Request = (@escaping Completion) -> Cancellable?

  private let request: Request
  private var completions: [RequestToken: Completion] = [:]
  private var currentRequestToken: Cancellable?

  public init(request: @escaping Request) {
    self.request = request
  }

  @discardableResult
  public func requestResource(completion: @escaping Completion) -> Cancellable? {
    if currentRequestToken == nil {
      guard let currentRequestToken = request({ [weak self] resource in
        self?.complete(resource: resource) }) else {
        return nil
      }
      self.currentRequestToken = currentRequestToken
    }
    let proxy = RequestToken(cancelAction: { cancellable in
      onMainThread { [weak self] in
        self?.cancel(cancellable: cancellable)
      }
    })
    completions[proxy] = completion
    return proxy
  }

  private func cancel(cancellable: RequestToken) {
    completions[cancellable] = nil
    if completions.isEmpty {
      currentRequestToken?.cancel()
      currentRequestToken = nil
    }
  }

  private func complete(resource: Resource?) {
    currentRequestToken = nil
    let completions = self.completions.values
    self.completions.removeAll()
    completions.forEach { $0(resource) }
  }
}

private final class RequestToken: Cancellable, Hashable {
  typealias CancelAction = @Sendable (RequestToken) -> Void

  private let cancelAction: CancelAction

  init(cancelAction: @escaping CancelAction) {
    self.cancelAction = cancelAction
  }

  func cancel() {
    cancelAction(self)
  }

  static func ==(lhs: RequestToken, rhs: RequestToken) -> Bool {
    lhs === rhs
  }

  public nonisolated func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self).hashValue)
  }
}
