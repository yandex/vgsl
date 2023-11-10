// Copyright 2021 Yandex LLC. All rights reserved.

// TODO(dmt021): @_spi(Extensions)
extension Set {
  @inlinable
  public static func union<T: Collection>(
    _ sets: T
  ) -> Set<Element> where T.Element == Set<Element> {
    sets.reduce(into: Set<Element>()) { $0.formUnion($1) }
  }
}
