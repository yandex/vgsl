// Copyright 2019 Yandex LLC. All rights reserved.

import Foundation

/// `ObservableVariableConnection` makes single
/// `ObservableVariable` (`target`) from other observable variables,
/// that are switching over time (`current`).
/// It is useful then source of some value changes, or arrives later.
/// It can also be used as property wrapper, `wrappedValue` sets a new source,
/// and gets the target.
@propertyWrapper
public struct ObservableVariableConnection<T> {
  private let impl: ObservableProperty<Signal<T>>
  public let target: ObservableVariable<T>

  public var source: Signal<T> {
    @available(*, unavailable, message: "source is set only, use target")
    get { impl.value }
    nonmutating set { impl.value = newValue }
  }

  public var current: ObservableVariable<T> {
    @available(*, unavailable, message: "current is set only, use target")
    get { ObservableVariable(initialValue: target.value, newValues: impl.value) }
    nonmutating set { impl.value = newValue.currentAndNewValues }
  }

  @inlinable
  public var value: T { target.value }

  public init(initialValue: T, newValues: ObservableProperty<Signal<T>>) {
    self.impl = newValues
    self.target = ObservableVariable(
      initialValue: initialValue,
      newValues: newValues.currentAndNewValues.flatMap { $0 }
    )
  }

  @inlinable
  public init(initial: ObservableVariable<T>) {
    self.init(
      initialValue: initial.value,
      newValues: ObservableProperty(initialValue: initial.newValues)
    )
  }

  @inlinable
  public init(initialValue: T) {
    self.init(initial: .constant(initialValue))
  }

  @inlinable
  public init<U>() where T == U? {
    self.init(initialValue: nil)
  }

  // MARK: Property wrapper

  @inlinable
  public init(wrappedValue: ObservableVariable<T>) {
    self.init(initial: wrappedValue)
  }

  @inlinable
  public var wrappedValue: ObservableVariable<T> {
    get { target }
    nonmutating set { current = newValue }
  }
}
