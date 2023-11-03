// Copyright 2023 Yandex LLC. All rights reserved.

extension Lazy {
  /// Deprecated. Will be removed in the near future.
  @inlinable
  public func asObservableVariable<U>(fallbackUntilLoaded: U) -> T
    where T == ObservableVariable<U> {
    if let currentValue {
      return currentValue
    }
    return future
      .asObservableVariable(fallbackUntilResolved: .constant(fallbackUntilLoaded))
      .flatten()
  }
}
