// Copyright 2021 Yandex LLC. All rights reserved.

// TODO(dmt021): @_spi(Extensions)
extension Set {
  @inlinable
  public static func union(
    _ sets: some Collection<Set<Element>>
  ) -> Set<Element> {
    sets.reduce(into: Set<Element>()) { $0.formUnion($1) }
  }
}
