// Copyright 2016 Yandex LLC. All rights reserved.

import Foundation

///
/// NB: if you use dynamic member lookup, consider following case:
///
/// ```
/// struct Struct {
///   var field: Int
/// }
///
/// let a = Property<Struct?>()
/// let b = a.field
/// a.value = Struct(value: 0)
/// b.value = nil
/// ```
///
/// What value should be in `a`?
/// Possible options:
/// 1. `Struct(value: 0)`
/// 2. `nil`
///
/// Due to ambiguity of this case, it is not supported (yet?)
///

/// A property wrapper that encapsulates a property with custom getter and setter logic.
/// It allows for sophisticated property management, including validation, transformation,
/// and notification of property value changes.
/// Usage Example:
/// ```
/// class User {
///  var name: String
///  var age: Int
///  ...
/// }
/// var user = User(name: "Alice", age: 30)
///
/// // Usage of Property to isolate a field of the User object using a key path
/// var isolatedAge = Property(user, refKeyPath: \.age)
///
/// // Now, we can directly access and modify the isolated age field
/// // without directly accessing the user object
///
/// print(isolatedAge.wrappedValue) // Output: 30
/// isolatedAge.wrappedValue += 1
/// print(user.age) // Output: 31
/// ```
@dynamicMemberLookup
@propertyWrapper
public struct Property<T> {
  /// A closure that returns the current value of the property. This enables custom logic
  /// for retrieving the property value.
  private let getter: () -> T

  /// A closure that accepts a new value for the property. This allows for custom logic
  /// to be executed when the property value is set, such as validation or transformation.
  private let setter: (T) -> Void

  /// The current value of the property. Accesses the getter when read, and invokes the setter when
  /// written to.
  public var wrappedValue: T {
    get { getter() }
    nonmutating set { setter(newValue) }
  }

  /// Provides a `Variable<T>` representation of this property, enabling observation of its value
  /// changes.
  @inlinable
  public var projectedValue: Variable<T> { asVariable() }

  #if DEBUG
  @usableFromInline
  let debugInfo: DebugInfo
  #else
  @inlinable
  var debugInfo: DebugInfo { DebugInfo() }
  #endif

  /// Initializes a `Property` with custom getter and setter closures.
  ///
  /// - Parameters:
  ///   - getter: A closure that returns the current value of the property.
  ///   - setter: A closure that is invoked with a new value to set the property.
  public init(getter: @escaping () -> T, setter: @escaping (T) -> Void) {
    self.init(getter: getter, setter: setter, ancestors: [])
  }

  @usableFromInline
  init(
    getter: @escaping () -> T,
    setter: @escaping (T) -> Void,
    ancestors: [DebugInfo]
  ) {
    self.getter = getter
    self.setter = setter
    #if DEBUG
    self.debugInfo = DebugInfo(callStack: Thread.callStackReturnAddresses, ancestors: ancestors)
    #endif
  }

  /// Convenience initializer that sets up a `Property` with an initial value.
  ///
  /// - Parameter wrappedValue: The initial value of the property.
  @inlinable
  public init(wrappedValue: T) {
    self.init(initialValue: wrappedValue)
  }
}

extension Property {
  /// Directly accesses or modifies the property's value, using the custom getter and setter.
  public var value: T {
    get { getter() }
    nonmutating set { setter(newValue) }
  }

  /// Enables the modification of nested properties via dynamic member lookup.
  /// This subscript returns a new `Property` instance wrapping the nested property, allowing
  /// for direct reads and writes to that property using the custom logic defined by `Property`.
  ///
  /// - Parameter path: A writable key path to a nested property of `T`.
  @inlinable
  public subscript<U>(dynamicMember path: WritableKeyPath<T, U>) -> Property<U> {
    Property<U>(
      getter: { self.value[keyPath: path] },
      setter: { self.value[keyPath: path] = $0 },
      ancestors: [debugInfo]
    )
  }

  /// Similar to the above subscript but specifically handles optional nested properties,
  /// allowing for nullable transformations and updates.
  @inlinable
  public subscript<ValueType, UnderlyingType>(
    dynamicMember path: WritableKeyPath<UnderlyingType, ValueType?>
  ) -> Property<ValueType?> where T == UnderlyingType? {
    Property<ValueType?>(
      getter: { self.value?[keyPath: path] },
      setter: { self.value?[keyPath: path] = $0 },
      ancestors: [debugInfo]
    )
  }

  /// Converts the `Property` into a `Variable<T>`, providing a read-only perspective.
  /// This is useful for scenarios where observation or reactive bindings are required without
  /// exposing write access.
  public func asVariable() -> Variable<T> {
    Variable(getter, ancestors: [debugInfo])
  }

  /// Initializes a `Property` with an initial value. This is a convenience initializer that
  /// sets up both getter and setter to work directly with a stored value.
  ///
  /// - Parameter initialValue: The initial value of the property.
  @inlinable
  public init(initialValue: T) {
    var value = initialValue
    self.init(
      getter: { value },
      setter: { value = $0 }
    )
  }

  /// Initializes a nullable `Property` with `nil` as its initial value.
  /// This initializer simplifies the creation of optional properties.
  @inlinable
  public init<U>() where T == U? {
    self.init(initialValue: nil)
  }

  /// Initializes a `Property` using a reference type object and a reference writable key path.
  /// This allows the property to directly modify a value within an object, providing a bridge
  /// between Swift's reference and value semantics.
  ///
  /// - Parameters:
  ///   - object: The object containing the value.
  ///   - refKeyPath: A reference writable key path to the value within the object.
  @inlinable
  public init<U>(_ object: U, refKeyPath: ReferenceWritableKeyPath<U, T>) {
    self.init(
      getter: { object[keyPath: refKeyPath] },
      setter: { object[keyPath: refKeyPath] = $0 }
    )
  }

  /// Transforms the property's value to another type, returning a new `Property` of the transformed
  /// type.
  /// This method allows for the encapsulation of transformation logic within the property access
  /// pattern.
  ///
  /// - Parameters:
  ///   - get: A transformation function from `T` to `U`.
  ///   - set: A transformation function from `U` back to `T`.
  public func bimap<U>(get: @escaping (T) -> U, set: @escaping (U) -> T) -> Property<U> {
    Property<U>(
      getter: compose(get, after: getter),
      setter: compose(setter, after: set),
      ancestors: [debugInfo]
    )
  }

  /// Similar to `bimap`, but allows for the modification of the value in place.
  /// This is useful for complex transformations where a value needs to be updated based on its
  /// current state.
  ///
  /// - Parameters:
  ///   - get: A transformation function from `T` to `U`.
  ///   - modify: A function that modifies the value of `T` in place, given a new value of `U`.
  public func bimap<U>(
    get: @escaping (T) -> U,
    modify: @escaping (inout T, U) -> Void
  ) -> Property<U> {
    Property<U>(
      getter: compose(get, after: getter),
      setter: { [getter, setter] value in setter(modified(getter()) { modify(&$0, value) }) },
      ancestors: [debugInfo]
    )
  }

  /// Provides a default value for an optional property, returning a non-optional `Property`.
  /// This is particularly useful for ensuring a property always has a value when accessed,
  /// even if the underlying value is `nil`.
  ///
  /// - Parameter defaultValue: The default value to use when the original value is `nil`.
  @inlinable
  public func withDefault<U>(_ defaultValue: U) -> Property<U> where T == U? {
    bimap(get: { $0 ?? defaultValue }, set: { $0 })
  }

  /// Converts the property into an `ObservableProperty`, enabling reactive observation patterns.
  /// This method is marked unsafe because it bypasses the safety checks typically provided by
  /// `ObservableProperty`.
  public func unsafeMakeObservable() -> ObservableProperty<T> {
    ObservableProperty(
      getter: getter,
      privateSetter: setter,
      ancestors: [debugInfo]
    )
  }
}

extension Property {
  /// Ensures that the property's getter and setter are only accessed on the main thread.
  /// This is crucial for properties that are tightly coupled with the UI, as UI updates
  /// must be performed on the main thread to prevent undefined behavior.
  ///
  /// - Returns: A `Property` instance that enforces main thread access.
  public func assertingMainThread() -> Property {
    Property(
      getter: { [getter] in
        Thread.assertIsMain()
        return getter()
      },
      setter: { [setter] value in
        Thread.assertIsMain()
        setter(value)
      },
      ancestors: [debugInfo]
    )
  }

  /// Creates a `Property` instance that holds a weak reference to its value.
  /// This is particularly useful for breaking retain cycles, especially in scenarios where
  /// the `Property` needs to reference a class instance that could potentially lead to a cycle.
  ///
  /// - Parameter initialValue: The initial value of the property, or `nil` if not provided.
  /// - Returns: A `Property` instance that holds a weak reference to its value..
  @inlinable
  public static func weak<U>(
    _ initialValue: U? = nil
  ) -> Self where T == U?, U: AnyObject {
    weak var value: U? = initialValue
    return .init(getter: { value }, setter: { value = $0 })
  }
}

extension Property {
  /// Creates a new `Property` instance that represents a nullable value of a dictionary's entry.
  /// This method allows for direct interaction with a nested value within a dictionary
  /// wrapped by a `Property`.
  /// It's especially useful for scenarios where you need to observe changes
  /// to a specific dictionary entry or modify it directly in a type-safe manner.
  ///
  /// - Parameter key: The key corresponding to the nested value within the dictionary
  /// to observe or modify.
  /// - Returns: A `Property<Value?>` that provides access to the dictionary's value
  /// for the specified key.
  /// This returned property can be used to observe changes to the value or modify it directly,
  /// and it will reflect the current state of the dictionary wrapped by the original `Property`.
  @inlinable
  public func descend<Key, Value>(to key: Key) -> Property<Value?>
    where Key: Hashable, T == [Key: Value] {
    Property<Value?>(
      getter: { self.value[key] },
      setter: { self.value[key] = $0 },
      ancestors: [debugInfo]
    )
  }
}

extension Property where T: ExpressibleByArrayLiteral {
  public init() {
    self.init(initialValue: [])
  }
}

extension Property where T: ExpressibleByNilLiteral {
  public init() {
    self.init(initialValue: nil)
  }
}

extension Property where T: ExpressibleByDictionaryLiteral {
  public init() {
    self.init(initialValue: [:])
  }
}

extension Property where T: ExpressibleByStringLiteral {
  public init() {
    self.init(initialValue: "")
  }
}

extension Property where T: ExpressibleByIntegerLiteral {
  public init() {
    self.init(initialValue: 0)
  }
}

extension Property where T: ExpressibleByBooleanLiteral {
  public init() {
    self.init(initialValue: false)
  }
}

extension Property: ExpressibleByBooleanLiteral where T == Bool {
  public init(booleanLiteral value: Bool) {
    self.init(initialValue: value)
  }
}

extension Property: ExpressibleByIntegerLiteral where T == Int {
  public init(integerLiteral value: Int) {
    self.init(initialValue: value)
  }
}

extension Property: ExpressibleByUnicodeScalarLiteral where T == String {}
extension Property: ExpressibleByExtendedGraphemeClusterLiteral where T == String {}

extension Property: ExpressibleByStringLiteral where T == String {
  public init(stringLiteral value: String) {
    self.init(initialValue: value)
  }
}
