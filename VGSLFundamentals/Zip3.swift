// Copyright 2023 Yandex LLC. All rights reserved.

public struct Zip3Sequence<Seq1: Sequence, Seq2: Sequence, Seq3: Sequence>: Sequence {
  public typealias Element = (Seq1.Element, Seq2.Element, Seq3.Element)

  public struct Iterator: IteratorProtocol {
    @usableFromInline
    internal var _it: (Seq1.Iterator, Seq2.Iterator, Seq3.Iterator)
    @usableFromInline // generic-performance
    internal var _isExhausted = false

    @inlinable
    internal init(
      _ it1: Seq1.Iterator,
      _ it2: Seq2.Iterator,
      _ it3: Seq3.Iterator
    ) {
      _it = (it1, it2, it3)
    }

    @inlinable
    public mutating func next() -> Element? {
      guard !_isExhausted else {
        return nil
      }
      guard
        let el1 = _it.0.next(),
        let el2 = _it.1.next(),
        let el3 = _it.2.next()
      else {
        _isExhausted = true
        return nil
      }
      return (el1, el2, el3)
    }
  }

  @usableFromInline
  internal let _seq: (Seq1, Seq2, Seq3)

  @inlinable
  internal init(_ seq1: Seq1, _ seq2: Seq2, _ seq3: Seq3) {
    _seq = (seq1, seq2, seq3)
  }

  public func makeIterator() -> Iterator {
    Iterator(
      _seq.0.makeIterator(),
      _seq.1.makeIterator(),
      _seq.2.makeIterator()
    )
  }
}

@inlinable
public func zip3<Seq1, Seq2, Seq3>(
  _ sequence1: Seq1,
  _ sequence2: Seq2,
  _ sequence3: Seq3
) -> Zip3Sequence<Seq1, Seq2, Seq3> {
  Zip3Sequence(sequence1, sequence2, sequence3)
}
