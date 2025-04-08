// Copyright 2021 Yandex LLC. All rights reserved.

import Foundation

private let assignmentQueue = DispatchQueue(
  label: "Memoization optimization assignment (for classes)",
  attributes: [.concurrent]
)

private func cachedValue<A: Sendable, B: Sendable>(
  from cache: Atomic<[A: B]>,
  for key: A,
  fallback: (A) throws -> B
) rethrows -> B {
  if let cachedValue = cache.accessRead({ $0[key] }) {
    return cachedValue
  }
  let value = try fallback(key)
  cache.accessWrite {
    $0[key] = value
  }
  return value
}

public func memoize<
  A: Hashable & Sendable,
  B: Sendable
>(_ f: @escaping @Sendable (A) throws -> B) -> @Sendable (A) throws -> B {
  let cache = Atomic(initialValue: [A: B]())
  return { (input: A) -> B in
    try cachedValue(from: cache, for: input, fallback: f)
  }
}

public func memoize<
  A: Hashable & Sendable,
  B: Sendable
>(_ f: @Sendable @escaping (A) -> B) -> @Sendable (A) -> B {
  let cache = Atomic(initialValue: [A: B]())
  return { (input: A) -> B in
    cachedValue(from: cache, for: input, fallback: f)
  }
}

public func memoizeNonSendable<A: Hashable, B>(_ f: @escaping (A) -> B) -> (A) -> B {
  var cache = [A: B]()
  return { (key: A) -> B in
    if let cachedValue = cache[key] {
      return cachedValue
    }
    let value = f(key)
    cache[key] = value
    return value
  }
}

private struct MemoizeParams2<A: Hashable & Sendable, B: Hashable & Sendable>: Hashable, Sendable {
  let a: A
  let b: B
}

private struct MemoizeParams2NonSendable<A: Hashable, B: Hashable>: Hashable {
  let a: A
  let b: B
}

public func memoize<
  A: Hashable & Sendable,
  B: Hashable & Sendable,
  C: Sendable
>(_ f: @escaping @Sendable (
  A,
  B
) -> C) -> @Sendable (A, B) -> C {
  let cache = Atomic(initialValue: [MemoizeParams2<A, B>: C]())
  return { (a: A, b: B) -> C in
    cachedValue(from: cache, for: MemoizeParams2(a: a, b: b), fallback: { f($0.a, $0.b) })
  }
}

public func memoizeNonSendable<
  A: Hashable,
  B: Hashable,
  C
>(_ f: @escaping (A, B) -> C) -> (A, B) -> C {
  var cache = [MemoizeParams2NonSendable<A, B>: C]()

  return { (a: A, b: B) -> C in
    let key = MemoizeParams2NonSendable(a: a, b: b)
    if let cachedValue = cache[key] {
      return cachedValue
    }
    let value = f(a, b)
    cache[key] = value
    return value
  }
}

private struct MemoizeParams3<
  A: Hashable & Sendable,
  B: Hashable & Sendable,
  C: Hashable & Sendable
>: Hashable, Sendable {
  let a: A
  let b: B
  let c: C
}

private struct MemoizeParams3NonSendable<
  A: Hashable,
  B: Hashable,
  C: Hashable
>: Hashable {
  let a: A
  let b: B
  let c: C
}

private final class MemoizeParams3AClass<
  A: Hashable & Sendable,
  B: Hashable & Sendable,
  C: Hashable & Sendable
>: Hashable, Sendable
  where A: AnyObject {
  var a: A {
    _a.withLock { $0 }
  }

  private let _a: AllocatedUnfairLock<A>
  let b: B
  let c: C

  init(a: sending A, b: B, c: C) {
    self._a = AllocatedUnfairLock(sendingState: a)
    self.b = b
    self.c = c
  }

  func hash(into hasher: inout Hasher) {
    a.hash(into: &hasher)
    b.hash(into: &hasher)
    c.hash(into: &hasher)
  }

  static func ==(lhs: MemoizeParams3AClass, rhs: MemoizeParams3AClass) -> Bool {
    // This code performs a very specific optimization for the case when
    // we put the calculations for the specific string (which has reference type) to the cache,
    // but _sometimes_ we re-create the instance of this string. Thus, if we don't modify
    // dictionary key, we'll always miss comparison by reference.
    // Here we rely on the implementation detail of Dictionary, namely we hope that
    // `lhs` corresponds to the key _already contained_ in dictionary and `rhs` corresponds
    // to the key by which we're trying to get the value.
    let aEquals = assignmentQueue.sync { lhs.a === rhs.a || lhs.a == rhs.a }
    if !aEquals {
      return false
    }

    assignmentQueue.sync(flags: .barrier) { lhs._a.withLock { $0 = rhs.a } }

    return lhs.b == rhs.b && lhs.c == rhs.c
  }
}

public func memoize<
  A: Hashable & Sendable,
  B: Hashable & Sendable,
  C: Hashable & Sendable,
  D: Sendable
>(_ f: @escaping @Sendable (A, B, C) -> D) -> @Sendable (A, B, C) -> D {
  let cache = Atomic(initialValue: [MemoizeParams3<A, B, C>: D]())
  return { (a: A, b: B, c: C) -> D in
    cachedValue(
      from: cache,
      for: MemoizeParams3(a: a, b: b, c: c),
      fallback: { f($0.a, $0.b, $0.c) }
    )
  }
}

public func memoizeNonSendable<
  A: Hashable,
  B: Hashable,
  C: Hashable,
  D
>(_ f: @escaping (A, B, C) -> D) -> (A, B, C) -> D {
  var cache = [MemoizeParams3NonSendable<A, B, C>: D]()
  return { (a: A, b: B, c: C) -> D in
    let key = MemoizeParams3NonSendable(a: a, b: b, c: c)
    if let cachedValue = cache[key] {
      return cachedValue
    }
    let value = f(a, b, c)
    cache[key] = value
    return value
  }
}

public func memoizeAClass<
  A: Hashable & Sendable,
  B: Hashable & Sendable,
  C: Hashable & Sendable,
  D: Sendable
>(_ f: @escaping (A, B, C) -> D) -> (A, B, C) -> D where A: AnyObject {
  let cache = Atomic(initialValue: [MemoizeParams3AClass<A, B, C>: D]())
  return { (a: A, b: B, c: C) -> D in
    cachedValue(
      from: cache,
      for: MemoizeParams3AClass(a: a, b: b, c: c),
      fallback: { f($0.a, $0.b, $0.c) }
    )
  }
}

private struct MemoizeParams4<
  A: Hashable & Sendable,
  B: Hashable & Sendable,
  C: Hashable & Sendable,
  D: Hashable & Sendable
>: Hashable, Sendable {
  let a: A
  let b: B
  let c: C
  let d: D
}

public func memoize<
  A: Hashable & Sendable,
  B: Hashable & Sendable,
  C: Hashable & Sendable,
  D: Hashable & Sendable,
  E: Sendable
>(_ f: @escaping @Sendable (A, B, C, D) -> E) -> @Sendable (A, B, C, D) -> E {
  let cache = Atomic(initialValue: [MemoizeParams4<A, B, C, D>: E]())
  return { (a: A, b: B, c: C, d: D) -> E in
    cachedValue(
      from: cache,
      for: MemoizeParams4(a: a, b: b, c: c, d: d),
      fallback: { f($0.a, $0.b, $0.c, $0.d) }
    )
  }
}

private struct MemoizeParams4NonSendable<
  A: Hashable,
  B: Hashable,
  C: Hashable,
  D: Hashable
>: Hashable {
  let a: A
  let b: B
  let c: C
  let d: D
}

public func memoizeNonSendable<
  A: Hashable,
  B: Hashable,
  C: Hashable,
  D: Hashable,
  E
>(_ f: @escaping (A, B, C, D) -> E) -> (A, B, C, D) -> E {
  var cache = [MemoizeParams4NonSendable<A, B, C, D>: E]()
  return { (a: A, b: B, c: C, d: D) -> E in
    let key = MemoizeParams4NonSendable(a: a, b: b, c: c, d: d)
    if let cachedValue = cache[key] {
      return cachedValue
    }
    let value = f(a, b, c, d)
    cache[key] = value
    return value
  }
}
