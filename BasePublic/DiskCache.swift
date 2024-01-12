// Copyright 2018 Yandex LLC. All rights reserved.

import Foundation

public final class DiskCache: Cache {
  private let cacheUrl: Lazy<URL>
  private let ioQueue: SerialOperationQueue
  private let fileManager: FileManaging
  private let log: (String) -> Void
  private let signpostStart: Action
  private let signpostEnd: Action

  private init(
    cacheUrl: Lazy<URL>,
    ioQueue: SerialOperationQueue,
    fileManager: FileManaging,
    log: @escaping (String) -> Void,
    signpostStart: @escaping Action,
    signpostEnd: @escaping Action
  ) {
    self.cacheUrl = cacheUrl
    self.ioQueue = ioQueue
    self.fileManager = fileManager
    self.log = log
    self.signpostStart = signpostStart
    self.signpostEnd = signpostEnd
  }

  public convenience init(
    in path: URL,
    ioQueue: SerialOperationQueue,
    fileManager: FileManaging = FileManager(),
    log: @escaping (String) -> Void = { _ in },
    signpostStart: @escaping Action = {},
    signpostEnd: @escaping Action = {}
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
      log: log,
      signpostStart: signpostStart,
      signpostEnd: signpostEnd
    )
    log("Initializing DiskCache in \(path)")
  }

  public convenience init(
    name: String,
    ioQueue queue: SerialOperationQueue,
    fileManager: FileManaging = FileManager(),
    log: @escaping (String) -> Void = { _ in },
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
      log: log,
      signpostStart: signpostStart,
      signpostEnd: signpostEnd
    )
    log("Initializing DiskCache with name '\(name)'")
  }

  public func retriveResource(
    forKey key: String,
    completion: @escaping (Result<Data, Error>) -> Void
  ) {
    ioQueue.addOperation { [self] in
      let cacheUrl = cacheUrl.value
      let url = url(forKey: key)
      let result: Result<Data, Error>
      do {
        let data = try fileManager.contents(at: url)
        log("DiskCache retrived a resource with key '\(key)' in \(cacheUrl)")
        result = .success(data)
      } catch {
        log(
          "DiskCache failed to retrive a resource with key '\(key)' in \(cacheUrl) with error: \(error)"
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
    completion: ((Result<Void, Error>) -> Void)?
  ) {
    ioQueue.addOperation { [self] in
      let cacheUrl = cacheUrl.value
      let result: Result<Void, Error>
      do {
        if !fileManager.fileExists(at: cacheUrl) {
          try fileManager.createDirectory(at: cacheUrl, withIntermediateDirectories: true)
        }
        let resourceUrl = url(forKey: key)
        try fileManager.createFile(at: resourceUrl, contents: data)
        log("DiskCache stored a resource with key '\(key)' in \(cacheUrl)")
        result = .success(())
      } catch {
        log(
          "DiskCache failed to store a resource with key '\(key)' in \(cacheUrl) with error: \(error)"
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

  private func url(forKey key: String) -> URL {
    let filename = key.percentEncoded()
    return cacheUrl.value.appendingPathComponent(filename)
  }
}
