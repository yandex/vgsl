// Copyright 2019 Yandex LLC. All rights reserved.

import Foundation

final class ParameterizedDiskCache<Storage: CacheStorage>: Cache
  where Storage.Item == CacheContent {
  typealias StorageFactory = ([CacheRecord]) -> Storage
  typealias ProvideRecords = (Storage) -> [CacheRecord]
  typealias SerializeRecords = ([CacheRecord]) throws -> Data
  typealias DeserializeRecords = (Data) throws -> [CacheRecord]
  typealias EncodeKey = (String) -> String

  private let cacheUrl: Lazy<URL>
  private let ioQueue: SerialOperationQueue
  private let mainThreadRunner: MainThreadRunner
  private let fileManager: FileManaging
  private var state: State<Storage> = .notLoaded
  private let storageFactory: StorageFactory
  private let provideRecords: ProvideRecords
  private let serializeRecords: SerializeRecords
  private let deserializeRecords: DeserializeRecords
  private let encodeKey: EncodeKey
  private let reportError: ((Error) -> Void)?

  init(
    cacheUrl: Lazy<URL>,
    ioQueue: SerialOperationQueue,
    mainThreadRunner: @escaping MainThreadRunner,
    fileManager: FileManaging,
    storageFactory: @escaping StorageFactory,
    provideRecords: @escaping ProvideRecords,
    serializeRecords: @escaping SerializeRecords,
    deserializeRecords: @escaping DeserializeRecords,
    encodeKey: @escaping EncodeKey,
    reportError: ((Error) -> Void)?
  ) {
    self.cacheUrl = cacheUrl
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

  func retriveResource(forKey key: String, completion: @escaping (Result<Data, Error>) -> Void) {
    Thread.assertIsMain()
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

  private func loadState() -> Storage {
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

  private func retrieveResource(storage: Storage, key: String) -> Result<Data, Error> {
    guard let content = storage.value(for: key) else {
      return .failure(ParameterizedDiskCacheErrors.keyNotFound)
    }
    switch content {
    case let .loaded(data):
      updateIndex(storage: storage)
      return .success(data)
    case .notLoaded:
      let url = self.url(forKey: key)
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

  private func updateIndex(storage: Storage) {
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
    completion: ((Result<Void, Error>) -> Void)?
  ) {
    Thread.assertIsMain()
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

  private func storeResource(
    key: String,
    data: Data,
    in storage: Storage
  ) -> Result<Void, Error> {
    let cacheUrl = self.cacheUrl.value
    do {
      if !fileManager.fileExists(at: cacheUrl) {
        try fileManager.createDirectory(at: cacheUrl, withIntermediateDirectories: true)
      }
      let url = self.url(forKey: key)
      try fileManager.createFile(at: url, contents: data)
      try add(key: key, value: .loaded(data), in: storage)
      updateIndex(storage: storage)
      return .success(())
    } catch {
      reportError?(error)
      return .failure(error as Error)
    }
  }

  private func add(key: String, value: CacheContent, in storage: Storage) throws {
    let evictedKeys = storage.add(key: key, item: value)
    try evictedKeys.rawValue.forEach {
      let url = self.url(forKey: $0)
      try fileManager.removeItem(at: url)
    }
  }

  func getResourceURL(forKey key: String) -> URL? {
    let targetURL = url(forKey: key)
    return fileManager.fileExists(at: targetURL) ? targetURL : nil
  }

  private func url(forKey key: String) -> URL {
    let filename = "file_\(encodeKey(key))"
    return cacheUrl.value.appendingPathComponent(filename)
  }

  private var cacheIndexURL: URL {
    let index = "index"
    return cacheUrl.value.appendingPathComponent(index)
  }
}

private enum State<Storage> {
  case notLoaded
  case loaded(storage: Storage)
}


enum ParameterizedDiskCacheErrors: Error {
  case keyNotFound
}
