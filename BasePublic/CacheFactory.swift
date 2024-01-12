// Copyright 2019 Yandex LLC. All rights reserved.

import Foundation

public enum CacheFactory {
  public static func makeLRUDiskCache(
    name: String,
    ioQueue queue: SerialOperationQueue,
    maxCapacity: UInt,
    reportError: ((Error) -> Void)?,
    signpostStart: @escaping Action = {},
    signpostEnd: @escaping Action = {}
  ) -> Cache {
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

    let storageFactory: ([CacheRecord])
      -> LRUCacheStorage<LinkedListOrderedDictionary<CacheContent>> = { records in
        let storage = LinkedListOrderedDictionary<CacheContent>(
          items: records.map { (key: $0.key, item: .notLoaded(size: $0.size)) }
        )
        return LRUCacheStorage(
          storage: storage,
          maxCapacity: maxCapacity
        )
      }
    return ParameterizedDiskCache<LRUCacheStorage<LinkedListOrderedDictionary<CacheContent>>>(
      cacheUrl: cacheUrl,
      ioQueue: queue,
      mainThreadRunner: onMainThread,
      fileManager: FileManager(),
      storageFactory: storageFactory,
      provideRecords: { $0.asArray() },
      serializeRecords: { try JSONEncoder().encode($0) },
      deserializeRecords: {
        try JSONDecoder()
          .decode([SafeDecodable<CacheRecord>].self, from: $0)
          .compactMap(\.value)
      },
      encodeKey: { $0.percentEncoded() },
      reportError: reportError
    )
  }
}
