// Copyright 2025 Yandex LLC. All rights reserved.

import Foundation

extension JSONDictionary {
  public mutating func setValue(_ value: JSONObject, atPath path: JSONObject.Path) throws {
    var jsonObject = JSONObject.object(self)
    try jsonObject.setValue(value, atPath: path)

    if case let .object(newDict) = jsonObject {
      self = newDict
    } else {
      throw JSONObject.Error.typeMismatch(
        subpath: path.asString,
        expected: "Object",
        received: jsonObject.shortDescription
      )
    }
  }

  @discardableResult
  public mutating func removeValue(atPath path: JSONObject.Path) throws -> JSONObject? {
    var jsonObject = JSONObject.object(self)
    let removedValue = try jsonObject.removeValue(atPath: path)

    if case let .object(newDict) = jsonObject {
      self = newDict
    } else {
      throw JSONObject.Error.typeMismatch(
        subpath: path.asString,
        expected: "Object",
        received: jsonObject.shortDescription
      )
    }
    return removedValue
  }
  
  public func allTerminalPaths() -> [JSONObject.Path] {
    JSONObject.object(self).allTerminalPaths()
  }
}

extension JSONObject {
  fileprivate mutating func setValue(_ value: JSONObject, atPath path: Path) throws {
    if path.components.isEmpty {
      self = value
      return
    }
    try setValue(value, components: path.components)
  }

  private mutating func setValue(
    _ value: JSONObject,
    components: [Path.Component],
    currentIndex: Int = 0
  ) throws {
    guard currentIndex < components.count else {
      self = value
      return
    }

    let component = components[currentIndex]
    let isLastComponent = currentIndex == components.count - 1

    switch (self, component) {
    case (var .object(dict), let .key(key)):
      if isLastComponent {
        dict[key] = value
      } else {
        if dict[key] == nil {
          let nextComponent = components[currentIndex + 1]
          switch nextComponent {
          case .key:
            dict[key] = .object([:])
          case .index:
            dict[key] = .array([])
          }
        }
        var nextValue = dict[key] ?? .null
        try nextValue.setValue(value, components: components, currentIndex: currentIndex + 1)
        dict[key] = nextValue
      }
      self = .object(dict)

    case (var .array(array), let .index(index)):
      while array.count <= index {
        array.append(.null)
      }

      if isLastComponent {
        array[index] = value
      } else {
        let nextComponent = components[currentIndex + 1]
        if case .null = array[index] {
          switch nextComponent {
          case .key:
            array[index] = .object([:])
          case .index:
            array[index] = .array([])
          }
        }
        var element = array[index]
        try element.setValue(value, components: components, currentIndex: currentIndex + 1)
        array[index] = element
      }
      self = .array(array)

    default:
      throw Error.typeMismatch(
        subpath: Path(components: components.prefix(currentIndex + 1).map { $0 }).asString,
        expected: component.expectedType,
        received: shortDescription
      )
    }
  }
}

extension JSONObject {
  @discardableResult
  fileprivate mutating func removeValue(atPath path: Path) throws -> JSONObject? {
    if path.components.isEmpty {
      throw Error.invalidPathComponent("Cannot remove root object")
    }
    return try removeValue(components: path.components)
  }

  private mutating func removeValue(
    components: [Path.Component]
  ) throws -> JSONObject? {
    guard let component = components.first else {
      return nil
    }

    let remainingComponents = components.dropFirst().map { $0 }
    let isLastComponent = remainingComponents.isEmpty

    switch (self, component) {
    case (var .object(dict), let .key(key)):
      guard let value = dict[key] else {
        return nil
      }
      if isLastComponent {
        let removed = dict.removeValue(forKey: key)
        self = .object(dict)
        return removed

      } else {
        var nestedValue = value
        let removedValue = try nestedValue.removeValue(components: remainingComponents)
        dict[key] = nestedValue
        self = .object(dict)
        return removedValue
      }

    case (var .array(array), let .index(index)):
      guard index < array.count else {
        return nil
      }
      if isLastComponent {
        let removedValue = array[index]
        array.remove(at: index)
        self = .array(array)
        return removedValue

      } else {
        var nestedValue = array[index]
        let removedValue = try nestedValue.removeValue(components: remainingComponents)
        array[index] = nestedValue
        self = .array(array)
        return removedValue
      }

    default:
      return nil
    }
  }
  
  fileprivate func allTerminalPaths() -> [Path] {
    switch self {
    case let .object(dict):
      dict.flatMap { key, element in
        element.allTerminalPaths().map { Path(component: .key(key)).appending(path: $0) }
      }
    case let .array(array):
      array.enumerated().flatMap { offset, element in
        element.allTerminalPaths().map { Path(component: .index(offset)).appending(path: $0) }
      }
    case .string, .number, .bool, .null:
      [.empty]
    }
  }
}
