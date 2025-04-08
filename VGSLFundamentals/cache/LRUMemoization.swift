// Copyright 2022 Yandex LLC. All rights reserved.

import Foundation

public func memoize<A, B: SizedItem & Sendable>(
  sizeLimit: UInt,
  keyMapper: @escaping @Sendable (A) -> String,
  _ f: @escaping @Sendable (A) -> B
) -> @Sendable (A) -> B {
  let storage = LinkedListOrderedDictionary<B>()
  let lruCache = SyncedCacheStorage(
    wrapee: LRUCacheStorage(storage: storage, maxCapacity: sizeLimit)
  )

  return { (input: A) -> B in
    lruCache.value(for: keyMapper(input), fallback: { f(input) })
  }
}

public func memoizeNonSendable<A, B: SizedItem>(
  sizeLimit: UInt,
  keyMapper: @escaping (A) -> String,
  _ f: @escaping (A) -> B
) -> (A) -> B {
  let storage = LinkedListOrderedDictionary<B>()
  let lruCache = LRUCacheStorage(storage: storage, maxCapacity: sizeLimit)

  return { (input: A) -> B in
    lruCache.value(for: keyMapper(input), fallback: { f(input) })
  }
}

public func memoize<A, B: Sendable>(
  sizeLimit: UInt,
  keyMapper: @escaping @Sendable (A) -> String,
  size: @escaping @Sendable (B) -> Int,
  _ f: @escaping @Sendable (A) -> B
) -> @Sendable (A) -> B {
  let makeWrapper: @Sendable (A) -> SizedWrapper<B> = {
    let result = f($0)
    return SizedWrapper(wrapee: result, size: size(result))
  }

  let memoizer = memoize(sizeLimit: sizeLimit, keyMapper: keyMapper, makeWrapper)
  return {
    memoizer($0).wrapee
  }
}

public func memoizeNonSendable<A, B>(
  sizeLimit: UInt,
  keyMapper: @escaping (A) -> String,
  size: @escaping (B) -> Int,
  _ f: @escaping (A) -> B
) -> (A) -> B {
  let makeWrapper: (A) -> SizedWrapperNonSendable<B> = {
    let result = f($0)
    return SizedWrapperNonSendable(wrapee: result, size: size(result))
  }

  let memoizer = memoizeNonSendable(sizeLimit: sizeLimit, keyMapper: keyMapper, makeWrapper)
  return {
    memoizer($0).wrapee
  }
}

public func memoize<A, B: Sendable>(
  sizeLimit: UInt,
  keyMapper: @escaping @Sendable (A) -> String,
  sizeByKey: @escaping @Sendable (A) -> Int,
  _ f: @escaping @Sendable (A) -> B
) -> @Sendable (A) -> B {
  let makeWrapper: @Sendable (A) -> SizedWrapper<B> = { SizedWrapper(
    wrapee: f($0),
    size: sizeByKey($0)
  ) }

  let memoizer = memoize(sizeLimit: sizeLimit, keyMapper: keyMapper, makeWrapper)
  return {
    memoizer($0).wrapee
  }
}

public func memoizeNonSendable<A, B: Sendable>(
  sizeLimit: UInt,
  keyMapper: @escaping (A) -> String,
  sizeByKey: @escaping (A) -> Int,
  _ f: @escaping (A) -> B
) -> (A) -> B {
  let makeWrapper: (A) -> SizedWrapper<B> = { SizedWrapper(wrapee: f($0), size: sizeByKey($0)) }
  let memoizer = memoizeNonSendable(sizeLimit: sizeLimit, keyMapper: keyMapper, makeWrapper)
  return {
    memoizer($0).wrapee
  }
}

private struct SizedWrapper<T: Sendable>: SizedItem, Sendable {
  let wrapee: T
  let size: Int
}

private struct SizedWrapperNonSendable<T>: SizedItem {
  let wrapee: T
  let size: Int
}

private final class SyncedCacheStorage<Storage: CacheStorage>: CacheStorage, Sendable
  where Storage.Item: SizedItem & Sendable {
  typealias Item = Storage.Item

  private let lock: AllocatedUnfairLock<Storage>

  init(wrapee: sending Storage) {
    self.lock = .init(sendingState: wrapee)
  }

  func add(key: String, item: Item) -> EvictedKeys {
    lock.withLock {
      $0.add(key: key, item: item)
    }
  }

  func value(for key: String) -> Item? {
    lock.withLock {
      $0.value(for: key)
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
