// Copyright 2023 Yandex LLC. All rights reserved.

@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
public struct AnyAsyncIterator<Element>: AsyncIteratorProtocol {
  @usableFromInline
  internal var _body: () async throws -> Element?

  @inlinable
  public init(_ body: @escaping () async throws -> Element?) {
    _body = body
  }

  @inlinable
  public func next() async throws -> Element? {
    try await _body()
  }
}

@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
public struct AnyAsyncSequence<Element>: AsyncSequence {
  @usableFromInline
  internal var _makeIterator: () -> AnyAsyncIterator<Element>

  @inlinable
  public init<S: AsyncSequence>(
    other: S
  ) where Element == S.Element {
    self.init {
      other.makeAsyncIterator()
    }
  }

  @inlinable
  public init<I: AsyncIteratorProtocol>(
    _ makeUnderlyingIterator: @escaping () -> I
  ) where Element == I.Element {
    _makeIterator = {
      var it = makeUnderlyingIterator()
      return AnyAsyncIterator {
        try await it.next()
      }
    }
  }

  @inlinable
  public func makeAsyncIterator() -> AnyAsyncIterator<Element> {
    _makeIterator()
  }
}
