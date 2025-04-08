// Copyright 2018 Yandex LLC. All rights reserved.

import Foundation

import VGSLFundamentals

@preconcurrency @MainActor
public final class CachedURLResourceRequester: URLResourceRequesting, LocalResourceURLProviding {
  public typealias CacheKeyBuilder = (URL) -> String

  private let cache: Cache
  private let cachemissRequester: URLResourceRequesting
  private let waitForCacheWrite: Bool
  private let cacheKeyBuilder: CacheKeyBuilder

  public init(
    cache: Cache,
    cachemissRequester: URLResourceRequesting,
    waitForCacheWrite: Bool = false,
    cacheKeyBuilder: CacheKeyBuilder? = nil
  ) {
    self.cache = cache
    self.cachemissRequester = cachemissRequester
    self.waitForCacheWrite = waitForCacheWrite
    self.cacheKeyBuilder = cacheKeyBuilder ?? CacheKey.make(fromURL:)
  }

  public func getDataWithSource(
    from url: URL,
    completion: @escaping CompletionHandlerWithSource
  ) -> Cancellable? {
    Thread.assertIsMain()
    let task = DeferredCancel(completion: completion)
    let key = cacheKeyBuilder(url)
    cache.retriveResource(forKey: key, completion: { result in
      switch result {
      case let .success(data):
        task.fulfill(result: .success(URLRequestResult(data: data, source: .cache)))
      case .failure:
        let cachemissTask = self.cachemissRequester.getDataWithSource(
          from: url,
          completion: { result in
            switch result {
            case let .success(data):
              self.cache.storeResource(data: data.data, forKey: key) { _ in
                if self.waitForCacheWrite {
                  task.fulfill(result: result)
                }
              }
              if !self.waitForCacheWrite {
                task.fulfill(result: result)
              }
            case .failure:
              task.fulfill(result: result)
            }
          }
        )
        task.underlyingCancellation = cachemissTask
      }
    })
    return task
  }

  public func getLocalResourceURL(with url: URL) -> URL? {
    cache.getResourceURL(forKey: cacheKeyBuilder(url))
  }
}

private final class DeferredCancel: Cancellable {
  private let isCancelled: AllocatedUnfairLock<Bool> = .init(initialState: false)
  private let completion: @MainActor (Result<URLRequestResult, NSError>) -> Void

  @MainActor
  var underlyingCancellation: Cancellable? {
    didSet {
      if isCancelled.withLock({ $0 }) {
        underlyingCancellation?.cancel()
      }
    }
  }

  init(completion: @escaping @MainActor (Result<URLRequestResult, NSError>) -> Void) {
    self.completion = completion
  }

  func cancel() {
    isCancelled.withLock { $0 = true }
    onMainThread { [self] in
      underlyingCancellation?.cancel()
    }
  }

  func fulfill(result: Result<URLRequestResult, NSError>) {
    Thread.assertIsMain()
    if !isCancelled.withLock({ $0 }) {
      onMainThread { [self] in
        completion(result)
      }
    }
  }
}
