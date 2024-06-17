// Copyright 2016 Yandex LLC. All rights reserved.

import Foundation

/// This abstraction provides an interface for safely observing value mutations.
/// It is similar to the CurrentValueSubject class in the Combine framework.
@dynamicMemberLookup
@propertyWrapper
public struct ObservableProperty<T> {
  /// A closure that returns the current value of the property, enabling dynamic computation.
  private let getter: () -> T

  /// A closure that sets a new value for the property, allowing for additional logic to be executed
  /// during assignment.
  private let setter: (T) -> Void

  /// A signal that emits new values of the property as they are set, facilitating observation and
  /// reactive responses.
  public let newValues: Signal<T>

  #if DEBUG
  @usableFromInline
  let debugInfo: DebugInfo
  #else
  @inlinable
  var debugInfo: DebugInfo { DebugInfo() }
  #endif

  /// Initializes an observable property with specified getter and setter closures, along with a
  /// signal for observing changes.
  /// This constructor is intentionally private to ensure controlled creation of observable
  /// properties, typically through factory methods or other initializer patterns that ensure
  /// proper signal handling.
  ///
  /// - Parameters:
  ///   - getter: A closure returning the current value of the property.
  ///   - setter: A closure accepting a new value for the property.
  ///   - newValues: A signal that emits whenever the property's value changes.
  private init(
    getter: @escaping () -> T,
    setter: @escaping (T) -> Void,
    newValues: Signal<T>,
    ancestors: [DebugInfo]
  ) {
    self.getter = getter
    self.setter = setter
    self.newValues = newValues
    #if DEBUG
    self.debugInfo = DebugInfo(callStack: Thread.callStackReturnAddresses, ancestors: ancestors)
    #endif
  }

  /// Accesses the current value of the property, invoking the getter on read
  /// and the setter on write.
  @inlinable
  public var wrappedValue: T {
    get { value }
    nonmutating set { value = newValue }
  }

  /// Provides an `ObservableVariable<T>` representation of the property, enabling direct
  /// interaction with the reactive layer for observation or binding to UI elements.
  @inlinable
  public var projectedValue: ObservableVariable<T> {
    asObservableVariable()
  }

  /// Enables direct access and modification of nested properties through dynamic member lookup.
  ///
  /// - Parameter path: A writable key path to a nested property.
  public subscript<U>(dynamicMember path: WritableKeyPath<T, U>) -> ObservableProperty<U> {
    ObservableProperty<U>(
      getter: { self.value[keyPath: path] },
      setter: { self.value[keyPath: path] = $0 },
      newValues: newValues.map { $0[keyPath: path] },
      ancestors: [debugInfo]
    )
  }

  /// Similar to the above subscript, but specifically designed for optional nested properties,
  /// facilitating optional chaining within observable structures.
  public subscript<ValueType, UnderlyingType>(
    dynamicMember path: WritableKeyPath<UnderlyingType, ValueType?>
  ) -> ObservableProperty<ValueType?> where T == UnderlyingType? {
    ObservableProperty<ValueType?>(
      getter: { self.value?[keyPath: path] },
      setter: { self.value?[keyPath: path] = $0 },
      newValues: newValues.map { $0?[keyPath: path] },
      ancestors: [debugInfo]
    )
  }
}

extension ObservableProperty {
  /// Accesses or modifies the current value of the property. Utilizes the custom getter for access
  /// and the custom setter for modifications, making it suitable for properties where side effects
  /// or validations are needed upon getting or setting a value.
  public var value: T {
    get { getter() }
    nonmutating set { setter(newValue) }
  }

  /// Converts this `ObservableProperty` to a `Variable<T>`, providing a read-only, non-observable
  /// interface.
  /// This can be useful when you want to expose the value for reading and observing is not
  /// required.
  public func asVariable() -> Variable<T> {
    Variable(getter, ancestors: [debugInfo])
  }

  /// Provides a read-only observable interface for the enclosed `value`.
  public func asObservableVariable() -> ObservableVariable<T> {
    ObservableVariable(
      getter: getter,
      newValues: newValues,
      ancestors: [debugInfo]
    )
  }

  /// Converts this `ObservableProperty` into a `Property<T>`, essentially providing a
  /// non-observable interface that still allows for custom getter and setter logic.
  /// This can be useful when observability is not required, but custom access patterns are.
  public func asProperty() -> Property<T> {
    Property(getter: getter, setter: setter, ancestors: [debugInfo])
  }

  /// Initializes the property with an initial value. This initializer creates an observable
  /// property that starts with a given value and updates reactively to changes.
  ///
  /// - Parameter initialValue: The initial value of the property.
  public init(initialValue: T) {
    self.init(initialValue: initialValue, ancestors: [])
  }

  @usableFromInline
  init(initialValue: T, ancestors: [DebugInfo]) {
    var value = initialValue
    self.init(
      getter: { value },
      privateSetter: { value = $0 },
      ancestors: ancestors
    )
  }

  /// A convenience initializer that allows for the initialization of the property with a wrapped
  /// value, simplifying the creation of an `ObservableProperty` with an initial value.
  @inlinable
  public init(wrappedValue: T) {
    self.init(initialValue: wrappedValue)
  }

  /// Initializes an optional `ObservableProperty` with `nil` as its initial value.
  /// This is particularly useful for optional properties that start as `nil` and may be set later.
  @inlinable
  public init<U>() where T == U? {
    self.init(initialValue: nil)
  }

  /// A signal that emits the current value immediately followed by new values as they are set.
  /// This enables subscribers to react to the initial state of the property as well as subsequent
  /// updates.
  public var currentAndNewValues: Signal<T> {
    newValues.startWith(getter)
  }

  /// Transforms the property's value to another type and returns a new `ObservableProperty` of the
  /// transformed type.
  /// This is useful for cases where you need to present or use the property's value
  /// in a different form.
  ///
  /// - Parameters:
  ///   - get: A transformation function from `T` to `U`.
  ///   - set: A transformation function from `U` back to `T`.
  public func bimap<U>(get: @escaping (T) -> U, set: @escaping (U) -> T) -> ObservableProperty<U> {
    ObservableProperty<U>(
      getter: compose(get, after: getter),
      setter: compose(setter, after: set),
      newValues: newValues.map(get),
      ancestors: [debugInfo]
    )
  }

  /// Provides a default value for an optional property, returning a non-optional
  /// `ObservableProperty`.
  /// This is useful for ensuring a property always has a value when accessed, even if the
  /// underlying value is `nil`.
  ///
  /// - Parameter defaultValue: The default value to use when the original value is `nil`.
  @inlinable
  public func withDefault<U>(_ defaultValue: U) -> ObservableProperty<U> where T == U? {
    bimap(get: { $0 ?? defaultValue }, set: { $0 })
  }
}

extension ObservableProperty {
  /// Initializes an `ObservableProperty` with specified getter and setter closures, while
  /// automatically creating a signal to observe changes. This initializer is designed for cases
  /// where the property's setter logic needs to remain encapsulated or private
  /// but still requires observation capabilities.
  ///
  /// - Parameters:
  ///   - getter: A closure returning the current value of the property. This enables dynamic
  /// computation or retrieval, adhering to the property wrapper's encapsulation of access patterns.
  ///   - privateSetter:  A closure that defines how the property's value is mutated. This closure
  /// is intended to encapsulate the mutation logic, providing a layer of abstraction over
  /// direct value assignment.
  /// The closure is marked `private` to emphasize its encapsulated role.
  init(
    getter: @escaping () -> T,
    privateSetter: @escaping (T) -> Void,
    ancestors: [DebugInfo]
  ) {
    let pipe = SignalPipe<T>()
    self.init(
      getter: getter,
      setter: {
        privateSetter($0)
        pipe.send($0)
      },
      newValues: pipe.signal,
      ancestors: ancestors
    )
  }
}

extension ObservableProperty {
  /// Ensures that the property's access and mutation are performed on the main thread.
  /// This method is particularly useful for properties that are bound to UI elements
  /// or require main-thread-only access for thread safety.
  ///
  /// - Returns: An `ObservableProperty` that asserts main thread access when its value is accessed
  /// or mutated.
  public func assertingMainThread() -> ObservableProperty {
    ObservableProperty(
      getter: { [getter] in
        Thread.assertIsMain()
        return getter()
      },
      setter: { [setter] in
        Thread.assertIsMain()
        setter($0)
      },
      newValues: newValues.assertingMainThread(),
      ancestors: [debugInfo]
    )
  }

  /// Creates an `ObservableProperty` that observes and controls a property of an `NSObject` via
  /// Key-Value Observing (KVO).
  ///
  /// - Parameters:
  ///   - keyPath: A key path referencing a writable property of an `NSObject`.
  ///   - object: The `NSObject` whose property is being observed and controlled.
  /// - Returns: An `ObservableProperty` tied to the specified key path of the given `NSObject`.
  public static func keyPath<Root: NSObject>(
    _ keyPath: ReferenceWritableKeyPath<Root, T>,
    onNSObject object: Root
  ) -> ObservableProperty {
    let newValues = Signal.changesForKeyPath(keyPath, onNSObject: object, options: .new)
      .compactMap(\.change.newValue)
    return ObservableProperty(
      getter: { object[keyPath: keyPath] },
      setter: { object[keyPath: keyPath] = $0 },
      newValues: newValues,
      ancestors: []
    )
  }

  /// Extends the lifetime of the specified object to match the lifetime of the
  /// `ObservableProperty`.
  /// This method is useful for scenarios where the property's getter or setter, or the generation
  /// of new values, depends on an object that may be deallocated prematurely.
  ///
  /// - Parameter object: An object whose lifetime should be extended to match that of the property.
  /// - Returns: An `ObservableProperty` that retains the specified object, ensuring it remains
  /// allocated as long as the property exists and is in use.
  public func retaining(_ object: some Any) -> Self {
    ObservableProperty(
      getter: {
        withExtendedLifetime(object) {
          self.getter()
        }
      },
      setter: { newValue in
        withExtendedLifetime(object) {
          self.setter(newValue)
        }
      },
      newValues: newValues.retaining(object: object),
      ancestors: [debugInfo]
    )
  }
}

extension ObservableProperty {
  /// Creates a new `ObservableProperty` instance that represents a specific entry in a dictionary,
  /// allowing for observation and modification of that entry. This method is particularly useful
  /// for working with dictionaries in a reactive programming context, enabling fine-grained control
  /// and observation of individual dictionary values.
  ///
  /// - Parameter key: The key of the dictionary entry to observe and modify.
  /// - Returns: An `ObservableProperty` instance that allows observing and setting the value for
  /// the specified key. The property's value is optional, accounting for the absence
  /// of the key in the dictionary.
  public func descend<Key, Value>(to key: Key) -> ObservableProperty<Value?>
    where Key: Hashable, T == [Key: Value] {
    ObservableProperty<Value?>(
      getter: { self.value[key] },
      setter: { self.value[key] = $0 },
      newValues: newValues.map { $0[key] },
      ancestors: [debugInfo]
    )
  }
}

extension ObservableProperty where T: Equatable {
  /// Modifies the property to skip repeated values before notifying observers. This prevents the
  /// `newValues` signal from emitting when the incoming value is equal
  /// to the current value of the property.
  /// It's particularly useful in reducing unnecessary updates and processing for observers
  /// that only need to react to distinct changes.
  ///
  /// - Returns: An `ObservableProperty` instance with the `skipRepeats` behavior applied.
  public func skipRepeats() -> Self {
    ObservableProperty(
      getter: getter,
      setter: setter,
      newValues: newValues.skipRepeats(initialValue: getter),
      ancestors: [debugInfo]
    )
  }

  /// Enum specifying possible modifications to apply to the `ObservableProperty`.
  public enum Modification {
    /// Modification to skip repeated values in the `newValues` signal.
    case skipRepeats
  }

  /// Initializes an `ObservableProperty` with an initial value and applies the specified
  /// modifications.
  /// This allows for configuring the property with behaviors such as `skipRepeats` directly upon
  /// initialization, streamlining the creation of properties with custom behaviors.
  ///
  /// - Parameters:
  ///   - initialValue: The initial value of the property.
  ///   - mods: An array of `Modification` specifying which modifications to apply.
  @inlinable
  public init(initialValue: T, _ mods: [Modification]) {
    var property = ObservableProperty(initialValue: initialValue)
    mods.forEach { mod in
      switch mod {
      case .skipRepeats:
        property = property.skipRepeats()
      }
    }
    self = property
  }

  /// Convenience initializer that takes a variable number of `Modification` parameters, allowing
  /// for an expressive and concise way to specify property behaviors.
  ///
  /// - Parameters:
  ///   - wrappedValue: The initial value of the property.
  ///   - mods: A variadic list of modifications to apply.
  @inlinable
  public init(wrappedValue: T, _ mods: Modification...) {
    self.init(initialValue: wrappedValue, mods)
  }
}

extension ObservableProperty where T: ExpressibleByArrayLiteral {
  public init() {
    self.init(initialValue: [])
  }
}

extension ObservableProperty where T: ExpressibleByNilLiteral {
  public init() {
    self.init(initialValue: nil)
  }
}

extension ObservableProperty where T: ExpressibleByDictionaryLiteral {
  public init() {
    self.init(initialValue: [:])
  }
}

extension ObservableProperty where T: ExpressibleByStringLiteral {
  public init() {
    self.init(initialValue: "")
  }
}

extension ObservableProperty where T: ExpressibleByIntegerLiteral {
  public init() {
    self.init(initialValue: 0)
  }
}

extension ObservableProperty where T: ExpressibleByBooleanLiteral {
  public init() {
    self.init(initialValue: false)
  }
}

extension ObservableProperty {
  /// Subscription to value changes.
  /// - Parameters:
  ///   - initial: Whether the signal should start from current value or first changed value.
  ///   - areEqual: A closure that checks if two values are equal.
  ///   - action: A closure called when value changes.
  /// This can be used to immediately react either to value changes
  /// or to the current state and then stay updated with changes skipping repeated values.
  @inlinable
  public func onChange(
    initial: Bool = false,
    areEqual: @escaping (T, T) -> Bool,
    _ action: @escaping (T) -> Void
  ) -> Disposable {
    asObservableVariable().onChange(initial: initial, areEqual: areEqual, action)
  }

  /// A signal that emits the current value if its value has changed.
  /// - Parameters:
  ///   - initial: Whether the signal should start from current value or first changed value.
  ///   - areEqual: A closure that checks if two values are equal.
  /// This can be used to immediately react either to value changes
  /// or to the current state and then stay updated with changes skipping repeated values.
  @inlinable
  public func changes(
    initial: Bool = false,
    areEqual: @escaping (T, T) -> Bool
  ) -> Signal<T> {
    asObservableVariable().changes(initial: initial, areEqual: areEqual)
  }
}

extension ObservableProperty where T: Equatable {
  /// Subscription to value changes.
  /// - Parameters:
  ///   - initial: Whether the signal should start from current value or first changed value.
  ///   - action: A closure called when value changes.
  /// This can be used to immediately react either to value changes
  /// or to the current state and then stay updated with changes skipping repeated values.
  @inlinable
  public func onChange(
    initial: Bool = false,
    _ action: @escaping (T) -> Void
  ) -> Disposable {
    asObservableVariable().onChange(initial: initial, action)
  }

  /// A signal that emits the current value if its value has changed.
  /// - Parameters:
  ///   - initial: Whether the signal should start from current value or first changed value.
  /// This can be used to immediately react either to value changes
  /// or to the current state and then stay updated with changes skipping repeated values.
  @inlinable
  public func changes(
    initial: Bool = false
  ) -> Signal<T> {
    asObservableVariable().changes(initial: initial)
  }
}
