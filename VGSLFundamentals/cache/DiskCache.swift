// Copyright 2018 Yandex LLC. All rights reserved.

import Foundation

public final class DiskCache: Cache {
  private let lazyCacheURL: Lazy<URL>
  private nonisolated(unsafe) var _cacheURL: URL?
  private nonisolated var cacheURL: URL {
    if let _cacheURL {
      return _cacheURL
    }

    return assumeIsolatedToMainActor {
      let result = lazyCacheURL.value
      _cacheURL = result
      return result
    }
  }

  private let ioQueue: SerialOperationQueue
  private let fileManager: FileManaging & Sendable
  private let log: @Sendable (String) -> Void

  private init(
    cacheUrl: Lazy<URL>,
    ioQueue: SerialOperationQueue,
    fileManager: FileManaging & Sendable,
    log: @escaping @Sendable (String) -> Void
  ) {
    self.lazyCacheURL = cacheUrl
    self.ioQueue = ioQueue
    self.fileManager = fileManager
    self.log = log
  }

  public convenience init(
    in path: URL,
    ioQueue: SerialOperationQueue,
    fileManager: FileManaging & Sendable,
    log: @escaping @Sendable (String) -> Void = { _ in },
    signpostStart: @escaping SendableAction = {},
    signpostEnd: @escaping SendableAction = {}
  ) {
    let cacheUrl = Lazy(getter: { () -> URL in
      signpostStart()
      defer { signpostEnd() }
      return path
    })
    self.init(
      cacheUrl: cacheUrl,
      ioQueue: ioQueue,
      fileManager: fileManager,
      log: log
    )
    log("Initializing DiskCache in \(path)")
  }

  public convenience init(
    name: String,
    ioQueue queue: SerialOperationQueue,
    fileManager: FileManaging & Sendable,
    log: @escaping @Sendable (String) -> Void = { _ in },
    signpostStart: @escaping Action = {},
    signpostEnd: @escaping Action = {}
  ) {
    let cacheUrl = Lazy(getter: { () -> URL in
      signpostStart()
      defer { signpostEnd() }
      let cacheDirectory = NSSearchPathForDirectoriesInDomains(
        .cachesDirectory,
        .userDomainMask,
        true
      ).first!
      let cacheDirectoryUrl = URL(fileURLWithPath: cacheDirectory)
      return cacheDirectoryUrl.appendingPathComponent(name)
    })
    self.init(
      cacheUrl: cacheUrl,
      ioQueue: queue,
      fileManager: fileManager,
      log: log
    )
    log("Initializing DiskCache with name '\(name)'")
  }

  public func retriveResource(
    forKey key: String,
    completion: @escaping @MainActor (Result<Data, Error>) -> Void
  ) {
    loadCacheURL()
    ioQueue.addOperation { [self] in
      let url = url(forKey: key)
      let result: Result<Data, Error>
      do {
        let data = try fileManager.contents(at: url)
        log("DiskCache retrived a resource with key '\(key)' in \(cacheURL)")
        result = .success(data)
      } catch {
        log(
          "DiskCache failed to retrive a resource with key '\(key)' in \(cacheURL) with error: \(error)"
        )
        result = .failure(error as Error)
      }
      onMainThread {
        completion(result)
      }
    }
  }

  public func storeResource(
    data: Data,
    forKey key: String,
    completion: (@MainActor (Result<Void, Error>) -> Void)?
  ) {
    loadCacheURL()
    ioQueue.addOperation { [self] in
      let result: Result<Void, Error>
      do {
        if !fileManager.fileExists(at: cacheURL) {
          try fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true)
        }
        let resourceUrl = url(forKey: key)
        try fileManager.createFile(at: resourceUrl, contents: data)
        log("DiskCache stored a resource with key '\(key)' in \(cacheURL)")
        result = .success(())
      } catch {
        log(
          "DiskCache failed to store a resource with key '\(key)' in \(cacheURL) with error: \(error)"
        )
        result = Result<Void, Error>.failure(error)
      }
      onMainThread {
        completion?(result)
      }
    }
  }

  public func getResourceURL(forKey key: String) -> URL? {
    let targetURL = url(forKey: key)
    return fileManager.fileExists(at: targetURL) ? targetURL : nil
  }

  private nonisolated func url(forKey key: String) -> URL {
    let filename = key.percentEncoded()
    return cacheURL.appendingPathComponent(filename)
  }

  private func loadCacheURL() {
    _ = cacheURL
  }
}
