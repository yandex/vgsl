// Copyright 2022 Yandex LLC. All rights reserved.

@resultBuilder
public enum ArrayBuilder<Element> {
  public typealias Component = [Element]
  public typealias Expression = Element

  @inlinable
  public static func buildExpression(_ element: Expression) -> Component {
    [element]
  }

  @inlinable
  public static func buildExpression(_ element: Expression?) -> Component {
    element.map { [$0] } ?? []
  }

  @inlinable
  public static func buildExpression(_ component: Component) -> Component {
    component
  }

  @inlinable
  public static func buildOptional(_ component: Component?) -> Component {
    component ?? []
  }

  @inlinable
  public static func buildEither(first component: Component) -> Component {
    component
  }

  @inlinable
  public static func buildEither(second component: Component) -> Component {
    component
  }

  @inlinable
  public static func buildArray(_ components: [Component]) -> Component {
    Array(components.joined())
  }

  @inlinable
  public static func buildBlock(_ components: Component...) -> Component {
    Array(components.joined())
  }

  @inlinable
  public static func build(@ArrayBuilder<Element> _ builder: () -> [Element]) -> [Element] {
    builder()
  }
}

// TODO(dmt021): @_spi(Extensions)
extension Array {
  @inlinable
  public static func build(
    @ArrayBuilder<Element> _ builder: () -> [Element]
  ) -> [Element] {
    builder()
  }
}
