// Copyright 2016 Yandex LLC. All rights reserved.

import Foundation

/// Convenience closure wrapper that takes Void as an argument and returns a value of a generic
/// type.
/// Unlike a closure, this is a property wrapper that allows for convenient operations
/// such as map, compactMap, and flatMap, as well as dynamic member lookup for the wrapped value.
/// Usage Example:
/// ```
/// struct User {
///     var name: String
///     var age: Int
/// }
///
/// class UserProfileViewModel {
///     private var user: User
///
///     @Variable var userName: String
///
///     init(user: User) {
///         self.user = user
///         // Initialize `_userName` with a closure that dynamically retrieves the user's name.
///         _userName = Variable { [weak self] in self?.user.name ?? "Unknown" }
///     }
/// }
///
/// let user = User(name: "Jane Doe", age: 28)
/// let viewModel = UserProfileViewModel(user: user)
/// print(viewModel.userName) // Output: "Jane Doe"
/// ```
@dynamicMemberLookup
@propertyWrapper
public struct Variable<T> {
  /// A closure that returns the current value of the variable. This closure is called
  /// every time the `wrappedValue` is accessed, allowing for dynamic computation of the value.
  @usableFromInline
  let getter: () -> T

  /// Provides read-only access to the variable's value. Accessing this property calls
  /// the `getter` closure to compute or retrieve the current value dynamically.
  @inlinable
  public var wrappedValue: T { getter() }

  /// Provides access to the observable variable itself, useful for binding and chaining operations.
  public var projectedValue: Self { self }

  #if DEBUG
  @usableFromInline
  let debugInfo: DebugInfo
  #else
  @inlinable
  var debugInfo: DebugInfo { DebugInfo() }
  #endif

  /// Initializes a new instance of `Variable` with a specified getter closure.
  /// This closure is used to define how the value of the variable is obtained
  /// whenever it is accessed. This design allows for flexibility in how the value
  /// is computed, including lazy computation or retrieval from another source.
  ///
  /// - Parameter getter: A closure that returns the current value of the variable.
  @inlinable
  public init(_ getter: @escaping () -> T) {
    self.init(getter, ancestors: [])
  }

  @usableFromInline
  init(_ getter: @escaping () -> T, ancestors: [DebugInfo]) {
    self.getter = getter
    #if DEBUG
    self.debugInfo = DebugInfo(callStack: Thread.callStackReturnAddresses, ancestors: ancestors)
    #endif
  }
}

extension Variable {
  /// Provides direct access to the variable's current value, utilizing the internal getter.
  @inlinable
  public var value: T {
    getter()
  }

  /// Enables dynamic member lookup that allows access to nested properties of the wrapped value.
  /// This subscript returns a new `Variable` instance wrapping the nested property.
  ///
  /// - Parameter path: A key path to the nested property of `T`.
  @inlinable
  public subscript<U>(dynamicMember path: KeyPath<T, U>) -> Variable<U> {
    Variable<U>({ self.value[keyPath: path] }, ancestors: [debugInfo])
  }

  /// Dynamic member lookup for optional `T` to access non-optional nested properties.
  @inlinable
  public subscript<ValueType, UnderlyingType>(
    dynamicMember path: KeyPath<UnderlyingType, ValueType>
  ) -> Variable<ValueType?> where T == UnderlyingType? {
    Variable<ValueType?>({ self.value?[keyPath: path] }, ancestors: [debugInfo])
  }

  /// Dynamic member lookup for optional `T` to access optional nested properties.
  @inlinable
  public subscript<ValueType, UnderlyingType>(
    dynamicMember path: KeyPath<UnderlyingType, ValueType?>
  ) -> Variable<ValueType?> where T == UnderlyingType? {
    Variable<ValueType?>({ self.value?[keyPath: path] }, ancestors: [debugInfo])
  }

  /// Creates a `Variable` instance that always returns a constant value.
  /// This is useful for creating variables that do not change over time.
  ///
  /// - Parameter value: The constant value to be returned by the variable.
  @inlinable
  public static func constant(_ value: T) -> Variable {
    Variable { value }
  }

  /// Initializes a `Variable` using a key path from an object. This allows the variable
  /// to dynamically access a property of the object.
  ///
  /// - Parameters:
  ///   - object: The object containing the property.
  ///   - keyPath: The key path to the property within the object.
  @inlinable
  public init<U>(_ object: U, keyPath: KeyPath<U, T>) {
    self.init { object[keyPath: keyPath] }
  }

  /// Initializes a new `Variable` by rewrapping another `Variable`'s value.
  /// This is useful for converting a `Variable` of one type to another when the types are
  /// compatible.
  ///
  /// - Parameter other: Another `Variable` instance to rewrap.
  @inlinable
  public init<U>(rewrap other: Variable<U>?) where T == U? {
    self.init({ other?.value }, ancestors: other.map { [$0.debugInfo] } ?? [])
  }

  /// Transforms the variable's value to another type, returning a new `Variable`
  /// of the transformed type.
  ///
  /// - Parameter transform: A closure that transforms the value from type `T` to type `U`.
  public func map<U>(_ transform: @escaping (T) -> U) -> Variable<U> {
    Variable<U>(compose(transform, after: getter), ancestors: [debugInfo])
  }

  /// Similar to `map`, but for transformations that themselves return a `Variable`.
  /// This allows for chaining transformations that involve dynamic properties.
  ///
  /// - Parameter transform: A closure that transforms the value from type `T` to a `Variable<U>`.
  public func flatMap<U>(
    _ transform: @escaping (T) -> Variable<U>
  ) -> Variable<U> {
    Variable<U>(
      compose(\.value, after: compose(transform, after: getter)),
      ancestors: [debugInfo]
    )
  }
}

extension Variable {
  /// Ensures that the variable's value is accessed on the main thread.
  /// This method is particularly useful in scenarios where the variable is bound to UI components,
  /// ensuring that all UI updates are performed on the main thread to prevent crashes or undefined
  /// behavior.
  public func assertingMainThread() -> Variable {
    Variable({ [getter] in
      Thread.assertIsMain()
      return getter()
    }, ancestors: [debugInfo])
  }
}

/// Combines two `Variable` instances into a single `Variable` that emits tuples of their current
/// values.
/// This is useful for creating dependencies between the values of two variables, allowing you to
/// react to changes in either variable in a synchronized manner.
@inlinable
public func zip<T, U>(_ lhs: Variable<T>, _ rhs: Variable<U>) -> Variable<(T, U)> {
  .init({ (lhs.value, rhs.value) }, ancestors: [lhs.debugInfo, rhs.debugInfo])
}

/// Combines three `Variable` instances into a single `Variable` that emits tuples of their current
/// values.
/// This extension of `zip` allows for the synchronization of three variables, which is particularly
/// useful when you need to combine or transform the values of three separate variables
/// into a single value or action.
@inlinable
public func zip3<T1, T2, T3>(
  _ v1: Variable<T1>, _ v2: Variable<T2>, _ v3: Variable<T3>
) -> Variable<(T1, T2, T3)> {
  Variable(
    { (v1.value, v2.value, v3.value) },
    ancestors: [v1.debugInfo, v2.debugInfo, v3.debugInfo]
  )
}

/// Combines four `Variable` instances into a single `Variable` that emits tuples of their current
/// values.
/// This function is useful for scenarios where the combined logic or transformation of four
/// variables is needed, allowing for a clean and synchronized way to react to changes
/// in any of the variables.
@inlinable
public func zip4<T1, T2, T3, T4>(
  _ v1: Variable<T1>, _ v2: Variable<T2>, _ v3: Variable<T3>, _ v4: Variable<T4>
) -> Variable<(T1, T2, T3, T4)> {
  Variable(
    { (v1.value, v2.value, v3.value, v4.value) },
    ancestors: [v1.debugInfo, v2.debugInfo, v3.debugInfo, v4.debugInfo]
  )
}
