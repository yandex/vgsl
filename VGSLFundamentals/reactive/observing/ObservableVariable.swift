// Copyright 2018 Yandex LLC. All rights reserved.

import Foundation

/// A property wrapper that enables observation of value changes. It is designed for use in reactive
/// programming patterns, allowing clients to subscribe to and react to updates
/// of the wrapped value.
/// This can be particularly useful in MVVM architectures
/// where view models can expose observable properties to views.
@dynamicMemberLookup
@propertyWrapper
public struct ObservableVariable<T> {
  /// The closure that returns the current value of the variable.
  private let getter: () -> T

  /// A signal representing the stream of new values as they are set. Subscribers to this signal can
  /// react to value changes in real time.
  public let newValues: Signal<T>

  #if DEBUG
  @usableFromInline
  let debugInfo: DebugInfo
  #else
  @inlinable
  var debugInfo: DebugInfo { DebugInfo() }
  #endif

  // Obsolete. Do not use in new code.
  // For class variables consider:
  //    private let observableXXXXStorage = ObservableProperty<T>
  //    var observableXXXX { observableXXXXStorage.asObservableVariable() }
  // For adapters consider:
  //     init(initialValue: T, newValues: Signal<T>)
  /// Initializes an observable variable with a getter for the current value and a signal for
  /// observing new values.
  /// This constructor is marked obsolete to encourage the use of `ObservableProperty<T>` for class
  /// properties and direct initialization with `initialValue` for adapters.
  /// - Parameters:
  ///   - getter: A closure that returns the current value of the variable.
  ///   - newValues: A signal that emits when the value changes.
  public init(
    getter: @escaping () -> T,
    newValues: Signal<T>
  ) {
    self.init(getter: getter, newValues: newValues, ancestors: [])
  }

  @usableFromInline
  init(
    getter: @escaping () -> T,
    newValues: Signal<T>,
    ancestors: [DebugInfo]
  ) {
    self.getter = getter
    self.newValues = newValues
    #if DEBUG
    self.debugInfo = DebugInfo(callStack: Thread.callStackReturnAddresses, ancestors: ancestors)
    #endif
  }

  /// Accessor for the current value of the variable. Reading this property will invoke the getter.
  public var wrappedValue: T { getter() }

  /// Provides access to the observable variable itself, useful for binding and chaining operations.
  public var projectedValue: Self { self }

  /// Enables dynamic member lookup to access and observe properties of nested objects.
  /// This subscript allows the observable variable to wrap and observe properties of `T`'s
  /// subproperties.
  @inlinable
  public subscript<U>(dynamicMember path: KeyPath<T, U>) -> ObservableVariable<U> {
    map { $0[keyPath: path] }
  }

  /// Subscript for dynamic member lookup that supports optional chaining for properties of `T`.
  @inlinable
  public subscript<ValueType, UnderlyingType>(
    dynamicMember path: KeyPath<UnderlyingType, ValueType>
  ) -> ObservableVariable<ValueType?> where T == UnderlyingType? {
    map { $0?[keyPath: path] }
  }

  /// Subscript for dynamic member lookup supporting optional chaining, specifically for optional
  /// properties of `T`.
  @inlinable
  public subscript<ValueType, UnderlyingType>(
    dynamicMember path: KeyPath<UnderlyingType, ValueType?>
  ) -> ObservableVariable<ValueType?> where T == UnderlyingType? {
    map { $0?[keyPath: path] }
  }
}

extension ObservableVariable {
  /// Accesses the current value of the variable.
  public var value: T {
    getter()
  }

  /// Converts this `ObservableVariable` into a non-observable `Variable<T>`.
  public func asVariable() -> Variable<T> {
    Variable(getter, ancestors: [debugInfo])
  }

  /// Creates an `ObservableVariable` that always emits the same value.
  /// Useful for creating constants in a reactive context.
  @inlinable
  public static func constant(_ value: T) -> ObservableVariable {
    ObservableVariable(getter: { value }, newValues: .empty)
  }

  /// A signal that emits the current value followed by all new values.
  /// This can be used to immediately react to the current state and then stay updated with changes.
  public var currentAndNewValues: Signal<T> {
    newValues.startWith(getter)
  }

  /// A signal that emits a tuple containing the previous and new value for each update.
  /// This is particularly useful for comparing old and new values in reactions.
  public var oldAndNewValues: Signal<(old: T?, new: T)> {
    var oldValue = self.getter()
    return Signal<(old: T?, new: T)>(addObserver: { observer in
      self.newValues.addObserver { newValue in
        observer.action((old: oldValue, new: newValue))
        oldValue = newValue
      }
    }).startWith { (old: nil, new: self.getter()) }
  }

  /// Transforms the variable's value to another type and returns a new `ObservableVariable` of that
  /// type.
  /// - Parameter transform: A function that converts `T` to `U`.
  public func map<U>(_ transform: @escaping (T) -> U) -> ObservableVariable<U> {
    ObservableVariable<U>(
      getter: compose(transform, after: getter),
      newValues: newValues.map(transform),
      ancestors: [debugInfo]
    )
  }

  /// Similar to `map`, but caches the last transformed value to improve performance
  /// and/or ensure consistency when the value is mapped to a reference type in order to prevent it
  /// from being initialized each time the mapped value is read.
  /// Useful for expensive transformations that should only be recomputed when necessary.
  @inlinable
  public func cachedMap<U>(_ transform: @escaping (T) -> U) -> ObservableVariable<U> {
    var current = transform(value)

    let pipe = SignalPipe<U>()
    let token = newValues.addObserver {
      current = transform($0)
      pipe.send(current)
    }
    return ObservableVariable<U>(
      getter: {
        withExtendedLifetime(token) {
          current
        }
      },
      newValues: Signal(addObserver: { observer in
        let outerToken = pipe.signal.addObserver(observer)
        return Disposable {
          withExtendedLifetime(token) { outerToken.dispose() }
        }
      }),
      ancestors: [debugInfo]
    )
  }

  /// Transforms the `ObservableVariable` to another `ObservableVariable` of a different type by
  /// applying a transformation that itself returns an `ObservableVariable`.
  /// - Parameter transform: A function that converts `T` to `ObservableVariable<U>`.
  public func flatMap<U>(
    _ transform: @escaping (T) -> ObservableVariable<U>
  ) -> ObservableVariable<U> {
    let newValues = self.newValues
      .map { transform($0).currentAndNewValues }
      .startWith { [getter] in transform(getter()).newValues }
      .flatMap { $0 }
    return ObservableVariable<U>(
      getter: { [getter] in transform(getter()).getter() },
      newValues: newValues,
      ancestors: [debugInfo]
    )
  }

  /// Flattens a nested `ObservableVariable<ObservableVariable<U>>` into a single
  /// `ObservableVariable<U>`.
  @inlinable
  public func flatten<U>() -> ObservableVariable<U> where T == ObservableVariable<U> {
    flatMap(identity(_:))
  }

  /// Filters nil values from an `ObservableVariable` and provides a default value when nil is
  /// encountered.
  /// - Parameters:
  ///   - valueIfNil: A closure that provides a default value when the original is nil.
  ///   - transform: A transformation function that might return nil.
  @inlinable
  public func compactMap<U>(
    valueIfNil: @autoclosure () -> U,
    _ transform: @escaping (T) -> U?
  ) -> ObservableVariable<U> {
    ObservableVariable<U>(
      initialValue: transform(value) ?? valueIfNil(),
      newValues: newValues.compactMap(transform),
      ancestors: [debugInfo]
    )
  }

  /// Creates a new `ObservableVariable` that only emits when the value has changed.
  /// - Parameter areEqual: A closure that checks if two values are equal.
  public func skipRepeats(areEqual: @escaping (T, T) -> Bool) -> ObservableVariable {
    ObservableVariable(
      getter: getter,
      newValues: newValues.skipRepeats(areEqual: areEqual, initialValue: getter),
      ancestors: [debugInfo]
    )
  }

  /// Wraps the value in a `Lazy<T>` and returns an `ObservableVariable<Lazy<T>>`.
  /// This can be used to delay computation or loading of the value until it's explicitly requested.
  @inlinable
  public var lazy: ObservableVariable<Lazy<T>> {
    ObservableVariable<Lazy<T>>(
      getter: { Lazy(getter: { self.value }) },
      newValues: newValues.map { Lazy(value: $0) },
      ancestors: [debugInfo]
    )
  }

  /// Combines this `ObservableVariable` with other signals, emitting a new value whenever any of
  /// the signals emit.
  /// - Parameter signals: A variadic list of `Signal<T>` to combine with this observable.
  @inlinable
  public func involving(_ signals: Signal<T>...) -> Self {
    involving(signals)
  }

  /// Combines this `ObservableVariable` with a collection of signals, emitting a new value whenever
  /// any of the signals emit.
  /// - Parameter signals: An array of `Signal<T>` to combine with this observable.
  @inlinable
  public func involving(_ signals: [Signal<T>]) -> Self {
    ObservableVariable(
      initialValue: value,
      newValues: .merge([newValues] + signals),
      ancestors: [debugInfo]
    )
  }
}

extension ObservableVariable where T: Equatable {
  /// Returns a new `ObservableVariable` that only emits a new value when the current value is
  /// different from the previous one.
  /// This helps in reducing unnecessary updates and processing.
  @inlinable
  public func skipRepeats() -> ObservableVariable {
    skipRepeats(areEqual: ==)
  }
}

extension ObservableVariable {
  /// Asserts that the variable is accessed on the main thread.
  /// This is particularly useful for variables bound to UI components, ensuring UI updates are
  /// performed safely.
  public func assertingMainThread() -> ObservableVariable {
    ObservableVariable(
      getter: { [getter] in
        Thread.assertIsMain()
        return getter()
      },
      newValues: newValues.assertingMainThread(),
      ancestors: [debugInfo]
    )
  }

  /// Creates an `ObservableVariable` that observes changes to a specific key path of an
  /// `NSObject`.
  /// This method leverages KVO (Key-Value Observing) to listen for changes and update the
  /// observable variable accordingly.
  /// - Parameters:
  ///   - keyPath: The key path to observe on the `NSObject`.
  ///   - object: The `NSObject` to observe.
  @inlinable
  public static func keyPath<Root: NSObject>(
    _ keyPath: KeyPath<Root, T>,
    onNSObject object: Root
  ) -> ObservableVariable {
    let newValues = Signal.changesForKeyPath(keyPath, onNSObject: object, options: .new)
      .compactMap(\.change.newValue)
    return ObservableVariable(
      getter: { object[keyPath: keyPath] },
      newValues: newValues
    )
  }
}

extension ObservableVariable {
  /// Creates an `ObservableVariable` instance that always returns `nil` and never emits new values.
  /// This can be useful in scenarios where a placeholder or optional chaining is needed.
  @inlinable
  public static func `nil`<U>() -> ObservableVariable where T == U? {
    ObservableVariable(getter: { nil }, newValues: .empty)
  }
}

/// Conformance to `ExpressibleByBooleanLiteral` for `ObservableVariable` instances where the
/// wrapped value is a `Bool`.
/// This allows for initializing an `ObservableVariable<Bool>` with a boolean literal.
extension ObservableVariable: ExpressibleByBooleanLiteral where T == Bool {
  /// Initializes an `ObservableVariable<Bool>` with a boolean literal.
  /// - Parameter value: The boolean literal to initialize the variable with.
  public init(booleanLiteral value: Bool) {
    self = .constant(value)
  }
}

extension ObservableVariable {
  /// This initializer stores the initial and intermediate values in the underlying storage
  /// Lifetime managment:
  /// `newValues: Signal<T>` is not retained
  /// `Disposable` of `newValues.addObserver()` is retained
  @inlinable
  public init(
    initialValue: T,
    newValues: Signal<T>
  ) {
    self.init(initialValue: initialValue, newValues: newValues, ancestors: [])
  }

  @usableFromInline
  init(
    initialValue: T,
    newValues: Signal<T>,
    ancestors: [DebugInfo]
  ) {
    var value = initialValue
    let pipe = SignalPipe<T>()
    let subscription = newValues.addObserver {
      value = $0
      pipe.send($0)
    }

    // keeps `subscription` alive as long as the `getter` is alive
    // to keep underlying `value` being updated regardless of losing
    // the `ObservableVariable.newValues`
    let getter: () -> T = {
      withExtendedLifetime(subscription) { value }
    }

    // keeps `subscription` alive as long as the `newValues` signal is alive
    // to keep receiving update events regardless of losing
    // the `ObservableVariable.getter`
    let newValues = pipe.signal.retaining(object: subscription)

    self.init(
      getter: getter,
      newValues: newValues,
      ancestors: ancestors
    )
  }
}

extension ObservableVariable {
  /// Ensures the given object is retained as long as this `ObservableVariable` exists.
  /// This method can be particularly useful to extend the lifetime of an object that is crucial
  /// for the computation or transformation of the variable's value.
  ///
  /// - Parameter object: The object to be retained.
  /// - Returns: An `ObservableVariable` that retains the specified object.
  @inlinable
  public func retaining(_ object: some Any) -> Self {
    ObservableVariable(
      initialValue: value,
      newValues: newValues.retaining(object: object),
      ancestors: [debugInfo]
    )
  }

  /// Transforms an `ObservableVariable` of optional values into an `ObservableVariable` of
  /// non-optional values,
  /// effectively grouping consecutive non-nil values into separate `ObservableVariable` instances.
  /// This method can be useful for dealing with streams of optional values where you want to react
  /// to sequences of non-nil values distinctly and ignore nil values.
  ///
  /// - Returns: An `ObservableVariable` of `ObservableVariable<U>?`, where each non-nil
  /// `ObservableVariable<U>` represents a sequence of non-nil values
  /// from the original `ObservableVariable`.
  ///
  /// Example:
  /// Consider an `ObservableVariable` emitting `[nil, nil, 1, 2, 3, nil, nil, 4, 5, nil]`.
  /// Using `collapseNils`, this would be transformed into `[nil, ObservableVariable([1, 2, 3]),
  /// nil, ObservableVariable([4, 5]), nil]`.
  @inlinable
  public func collapseNils<U>() -> ObservableVariable<ObservableVariable<U>?> where T == U? {
    @ObservableProperty
    var outer: ObservableVariable<U>? = nil

    var inner: ObservableProperty<U>?

    let subscription = currentAndNewValues.addObserver { state in
      guard let state else {
        if inner != nil {
          _outer.wrappedValue = nil
          inner = nil
        }
        return
      }
      if let inner {
        inner.value = state
      } else {
        let localInner = ObservableProperty(
          initialValue: state,
          ancestors: [debugInfo]
        )
        _outer.wrappedValue = localInner.asObservableVariable()
        inner = localInner
      }
    }

    return $outer.retaining(subscription)
  }
}

extension ObservableVariable {
  /// Generates a multiplexed version of the current `ObservableVariable`, allowing observers to
  /// access both the observable variable and a distinct signal that emits values immediately after
  /// the variable updates.
  /// This setup is especially useful for scenarios requiring actions or reactions right after the
  /// variable's value changes.
  ///
  /// - Returns: A tuple consisting of the original `ObservableVariable` and an `afterUpdateSignal`.
  ///   - `variable`: The same observable variable, enabling continuous observation of its value
  /// changes.
  ///   - `afterUpdateSignal`: A signal that emits the new value immediately after each update to
  /// the variable. This signal can be used to trigger actions that should occur right after the
  /// variable updates, such as animations, logging, or other side effects.
  @inlinable
  public func multiplexed() -> (variable: Self, afterUpdateSignal: Signal<T>) {
    var value = value
    let afterUpdatePipe = SignalPipe<T>()
    let pipe = SignalPipe<T>()

    let subscription = newValues.addObserver {
      value = $0
      pipe.send($0)
      afterUpdatePipe.send($0)
    }

    let modelVariable = ObservableVariable(
      initialValue: value,
      newValues: pipe.signal,
      ancestors: [debugInfo]
    )
    return (
      variable: modelVariable.retaining(subscription),
      afterUpdateSignal: afterUpdatePipe.signal.retaining(object: subscription)
    )
  }
}

extension ObservableVariable {
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
    changes(initial: initial, areEqual: areEqual).addObserver(action)
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
    let ov = skipRepeats(areEqual: areEqual)
    return initial ? ov.currentAndNewValues : ov.newValues
  }
}

extension ObservableVariable where T: Equatable {
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
    changes(initial: initial).addObserver(action)
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
    let ov = skipRepeats()
    return initial ? ov.currentAndNewValues : ov.newValues
  }
}
