// Copyright 2019 Yandex LLC. All rights reserved.

import Foundation

final class ParameterizedDiskCache<Storage: CacheStorage>: Cache
  where Storage.Item == CacheContent {
  typealias StorageFactory = @Sendable ([CacheRecord]) -> Storage
  typealias ProvideRecords = @Sendable (Storage) -> [CacheRecord]
  typealias SerializeRecords = @Sendable ([CacheRecord]) throws -> Data
  typealias DeserializeRecords = @Sendable (Data) throws -> [CacheRecord]
  typealias EncodeKey = @Sendable (String) -> String

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
  private let mainThreadRunner: MainThreadRunner
  private let fileManager: FileManaging & Sendable
  private nonisolated(unsafe) var state: State<Storage> = .notLoaded
  private let storageFactory: StorageFactory
  private let provideRecords: ProvideRecords
  private let serializeRecords: SerializeRecords
  private let deserializeRecords: DeserializeRecords
  private let encodeKey: EncodeKey
  private let reportError: (@Sendable (Error) -> Void)?

  init(
    cacheUrl: Lazy<URL>,
    ioQueue: SerialOperationQueue,
    mainThreadRunner: @escaping MainThreadRunner,
    fileManager: FileManaging & Sendable,
    storageFactory: @escaping StorageFactory,
    provideRecords: @escaping ProvideRecords,
    serializeRecords: @escaping SerializeRecords,
    deserializeRecords: @escaping DeserializeRecords,
    encodeKey: @escaping EncodeKey,
    reportError: (@Sendable (Error) -> Void)?
  ) {
    lazyCacheURL = cacheUrl
    self.ioQueue = ioQueue
    self.mainThreadRunner = mainThreadRunner
    self.fileManager = fileManager
    self.storageFactory = storageFactory
    self.provideRecords = provideRecords
    self.serializeRecords = serializeRecords
    self.deserializeRecords = deserializeRecords
    self.encodeKey = encodeKey
    self.reportError = reportError
  }

  func retriveResource(
    forKey key: String,
    completion: @escaping @MainActor (Result<Data, Error>) -> Void
  ) {
    Thread.assertIsMain()
    loadCacheURL()
    ioQueue.addOperation {
      let result: Result<Data, Error>
      switch self.state {
      case .notLoaded:
        let storage = self.loadState()
        self.state = .loaded(storage: storage)
        result = self.retrieveResource(storage: storage, key: key)
      case let .loaded(storage: storage):
        result = self.retrieveResource(storage: storage, key: key)
      }
      self.mainThreadRunner {
        completion(result)
      }
    }
  }

  private nonisolated func loadState() -> Storage {
    guard fileManager.fileExists(at: cacheIndexURL) else {
      return storageFactory([])
    }
    let records: [CacheRecord]
    do {
      let recordsData = try fileManager.contents(at: cacheIndexURL)
      records = try deserializeRecords(recordsData)
    } catch {
      records = []
      reportError?(error)
    }
    return storageFactory(records)
  }

  private nonisolated func retrieveResource(storage: Storage, key: String) -> Result<Data, Error> {
    guard let content = storage.value(for: key) else {
      return .failure(ParameterizedDiskCacheErrors.keyNotFound)
    }
    switch content {
    case let .loaded(data):
      updateIndex(storage: storage)
      return .success(data)
    case .notLoaded:
      let url = url(forKey: key)
      do {
        let data = try fileManager.contents(at: url)
        try add(key: key, value: .loaded(data), in: storage)
        updateIndex(storage: storage)
        return .success(data)
      } catch {
        reportError?(error)
        return .failure(error as Error)
      }
    }
  }

  private nonisolated func updateIndex(storage: Storage) {
    do {
      let records = provideRecords(storage)
      let data = try serializeRecords(records)
      try fileManager.createFile(at: cacheIndexURL, contents: data)
    } catch {
      reportError?(error)
    }
  }

  func storeResource(
    data: Data,
    forKey key: String,
    completion: (@MainActor (Result<Void, Error>) -> Void)?
  ) {
    Thread.assertIsMain()
    loadCacheURL()
    ioQueue.addOperation {
      let result: Result<Void, Error>
      switch self.state {
      case .notLoaded:
        let storage = self.loadState()
        self.state = .loaded(storage: storage)
        result = self.storeResource(key: key, data: data, in: storage)
      case let .loaded(storage: storage):
        result = self.storeResource(key: key, data: data, in: storage)
      }
      self.mainThreadRunner {
        completion?(result)
      }
    }
  }

  private nonisolated func storeResource(
    key: String,
    data: Data,
    in storage: Storage
  ) -> Result<Void, Error> {
    do {
      if !fileManager.fileExists(at: cacheURL) {
        try fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true)
      }
      let url = url(forKey: key)
      try fileManager.createFile(at: url, contents: data)
      try add(key: key, value: .loaded(data), in: storage)
      updateIndex(storage: storage)
      return .success(())
    } catch {
      reportError?(error)
      return .failure(error as Error)
    }
  }

  private func loadCacheURL() {
    _ = cacheURL
  }

  private nonisolated func add(key: String, value: CacheContent, in storage: Storage) throws {
    let evictedKeys = storage.add(key: key, item: value)
    try evictedKeys.rawValue.forEach {
      let url = self.url(forKey: $0)
      try fileManager.removeItem(at: url)
    }
  }

  func getResourceURL(forKey key: String) -> URL? {
    loadCacheURL()
    let targetURL = url(forKey: key)
    return fileManager.fileExists(at: targetURL) ? targetURL : nil
  }

  private nonisolated func url(forKey key: String) -> URL {
    assert(_cacheURL != nil)
    let filename = "file_\(encodeKey(key))"
    return cacheURL.appendingPathComponent(filename)
  }

  private nonisolated var cacheIndexURL: URL {
    assert(_cacheURL != nil)
    let index = "index"
    return cacheURL.appendingPathComponent(index)
  }
}

private enum State<Storage> {
  case notLoaded
  case loaded(storage: Storage)
}

extension State: Sendable where Storage: Sendable {}

enum ParameterizedDiskCacheErrors: Error {
  case keyNotFound
}
