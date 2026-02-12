// Copyright 2018 Yandex LLC. All rights reserved.

import Foundation

@dynamicMemberLookup
public final class Lazy<T> {
  public typealias Getter = () -> T

  private static func makeOneShotGetter(_ getter: @escaping Getter) -> Getter {
    var state = Either<Getter, T>.left(getter)
    return {
      switch state {
      case let .left(getter):
        let result = getter()
        state = .right(result)
        return result
      case let .right(value):
        return value
      }
    }
  }

  private let impl: ResettableLazy<T>

  public var value: T {
    impl.value
  }

  public var currentValue: T? {
    impl.currentValue
  }

  public convenience init(getter: @escaping Getter) {
    self.init(impl: ResettableLazy(getter: Self.makeOneShotGetter(getter)))
  }

  public convenience init(onMainThreadGetter getter: @escaping Getter) {
    self.init(impl: ResettableLazy(onMainThreadGetter: Self.makeOneShotGetter(getter)))
  }

  public convenience init(preload: @escaping () -> Void, getter: @escaping () -> T) {
    self.init(impl: ResettableLazy(preload: preload, getter: Self.makeOneShotGetter(getter)))
  }

  /// Produces a Lazy in not loaded state with a given value.
  ///
  /// Even thou the value is already on hands the resulting Lazy will
  /// behave like it was created with a getter, and `currentValue`
  /// will be `nil` until the Lazy is read.
  /// Use `init(loaded:)` when you need a Lazy in loaded state.
  public convenience init(value: T) {
    self.init(impl: ResettableLazy(value: value))
  }

  /// Produces a Lazy in loaded state with a given value.
  ///
  /// The resulting Lazy will immediately have a non-nil `currentValue`.
  public convenience init(loaded value: T) {
    self.init(impl: ResettableLazy(loaded: value))
  }

  private init(impl: ResettableLazy<T>) {
    self.impl = impl
  }

  public var future: Future<T> {
    impl.future
  }

  public func whenLoaded(perform body: @escaping Future<T>.Callback) {
    impl.whenLoaded(perform: body)
  }

  public func ensureIsLoaded() {
    impl.ensureIsLoaded()
  }

  /// Transforms this lazy into a new one **eagerly**.
  ///
  /// Resulting Lazy will be **loaded right after the current one loads**.
  /// Resulting Lazy will also contain a copy of the result of transformation.
  /// `transform` will be invoked once.
  /// `future` of the resulting Lazy will be resolved once the parent future is resolved.
  /// Use this function only if you intend to load the value **eagerly**.
  /// Otherwise consider other types of transformation,
  /// i.e. `Lazy(getter: { someTransformation(anotherLazy.value) })`
  /// or `lazyMap { someTransformation($0) }`.
  public func map<U>(_ transform: @escaping (T) -> U) -> Lazy<U> {
    Lazy<U>(impl: impl.map(transform))
  }

  /// Same as `map`, but the transformation is performed lazily
  /// (resulting lazy is not loaded when the current one loads).
  public func lazyMap<U>(_ transform: @escaping (T) -> U) -> Lazy<U> {
    Lazy<U>(impl: impl.lazyMap(transform))
  }

  public subscript<U>(dynamicMember path: KeyPath<T, U>) -> Lazy<U> {
    Lazy<U>(impl: impl[dynamicMember: path])
  }
}
