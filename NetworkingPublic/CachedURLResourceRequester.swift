// Copyright 2018 Yandex LLC. All rights reserved.

import Foundation

import BasePublic

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
      if let result = result.value() {
        task.fulfill(result: .success(URLRequestResult(data: result, source: .cache)))
        return
      }
      let cachemissTask = self.cachemissRequester.getDataWithSource(
        from: url,
        completion: { result in
          if let data = result.value() {
            self.cache.storeResource(data: data.data, forKey: key) { _ in
              if self.waitForCacheWrite {
                task.fulfill(result: result)
              }
            }
          }
          if !self.waitForCacheWrite {
            task.fulfill(result: result)
          }
        }
      )
      task.underlyingCancellation = cachemissTask
    })
    return task
  }

  public func getLocalResourceURL(with url: URL) -> URL? {
    cache.getResourceURL(forKey: cacheKeyBuilder(url))
  }
}

private class DeferredCancel: Cancellable {
  private var isCancelled = false
  private let completion: (Result<URLRequestResult, NSError>) -> Void
  var underlyingCancellation: Cancellable? {
    didSet {
      Thread.assertIsMain()
      if isCancelled {
        underlyingCancellation?.cancel()
      }
    }
  }

  init(completion: @escaping (Result<URLRequestResult, NSError>) -> Void) {
    self.completion = completion
  }

  func cancel() {
    Thread.assertIsMain()
    isCancelled = true
    underlyingCancellation?.cancel()
  }

  func fulfill(result: Result<URLRequestResult, NSError>) {
    Thread.assertIsMain()
    if !isCancelled {
      completion(result)
    }
  }
}
