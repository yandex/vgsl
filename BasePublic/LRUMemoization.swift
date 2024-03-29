// Copyright 2022 Yandex LLC. All rights reserved.

import Foundation

public func memoize<A, B: SizedItem>(
  sizeLimit: UInt,
  keyMapper: @escaping (A) -> String,
  _ f: @escaping (A) -> B
) -> (A) -> B {
  let storage = LinkedListOrderedDictionary<B>()
  let lruCache = SyncedCacheStorage(
    wrapee: LRUCacheStorage(storage: storage, maxCapacity: sizeLimit)
  )

  return { (input: A) -> B in
    lruCache.value(for: keyMapper(input), fallback: { f(input) })
  }
}

public func memoize<A, B>(
  sizeLimit: UInt,
  keyMapper: @escaping (A) -> String,
  size: @escaping (B) -> Int,
  _ f: @escaping (A) -> B
) -> (A) -> B {
  let makeWrapper: (A) -> SizedWrapper<B> = {
    let result = f($0)
    return SizedWrapper(wrapee: result, size: size(result))
  }

  return compose(
    \.wrapee,
    after: memoize(sizeLimit: sizeLimit, keyMapper: keyMapper, makeWrapper)
  )
}

public func memoize<A, B>(
  sizeLimit: UInt,
  keyMapper: @escaping (A) -> String,
  sizeByKey: @escaping (A) -> Int,
  _ f: @escaping (A) -> B
) -> (A) -> B {
  let makeWrapper: (A) -> SizedWrapper<B> = { SizedWrapper(wrapee: f($0), size: sizeByKey($0)) }
  return compose(
    \.wrapee,
    after: memoize(sizeLimit: sizeLimit, keyMapper: keyMapper, makeWrapper)
  )
}

private struct SizedWrapper<T>: SizedItem {
  let wrapee: T
  let size: Int
}

private class SyncedCacheStorage<Storage: CacheStorage>: CacheStorage
  where Storage.Item: SizedItem {
  typealias Item = Storage.Item

  private let lock = AllocatedUnfairLock()
  private let wrapee: Storage

  init(wrapee: Storage) {
    self.wrapee = wrapee
  }

  func add(key: String, item: Item) -> EvictedKeys {
    lock.withLock {
      wrapee.add(key: key, item: item)
    }
  }

  func value(for key: String) -> Item? {
    lock.withLock {
      wrapee.value(for: key)
    }
  }
}

extension CacheStorage {
  fileprivate func value(for key: String, fallback: () -> Item) -> Item {
    if let cachedValue = value(for: key) {
      return cachedValue
    }
    let value = fallback()
    _ = add(key: key, item: value)
    return value
  }
}
