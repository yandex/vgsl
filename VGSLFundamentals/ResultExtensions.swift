// Copyright 2021 Yandex LLC. All rights reserved.

// TODO(dmt021): @_spi(Extensions)
extension Result {
  @inlinable
  public func map<U>(_ transform: (Success) throws -> U) -> Result<U, Error> {
    switch self {
    case let .success(value):
      do {
        return try .success(transform(value))
      } catch {
        return .failure(error)
      }
    case let .failure(error):
      return .failure(error)
    }
  }

  @inlinable
  public func map<U>(_ transform: (Success) -> U) -> Result<U, Failure> {
    switch self {
    case let .success(value):
      return .success(transform(value))
    case let .failure(error):
      return .failure(error)
    }
  }

  @inlinable
  public func bimap<U>(
    _ transformValue: (Success) throws -> U,
    transfromError: (Failure) throws -> U
  ) rethrows -> U {
    switch self {
    case let .success(value):
      return try transformValue(value)
    case let .failure(err):
      return try transfromError(err)
    }
  }
}
