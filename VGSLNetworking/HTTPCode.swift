// Copyright 2018 Yandex LLC. All rights reserved.

public enum HTTPCode: Int, RawRepresentable, CaseIterable, Sendable {
  case ok
  case noContent
  case unauthorized
  case forbidden
  case notFound
  case conflict
  case other

  public typealias RawValue = Int

  public init(rawValue: Int?) {
    guard let rawValue else {
      self = .other
      return
    }

    switch rawValue {
    case 200:
      self = .ok
    case 204:
      self = .noContent
    case 401:
      self = .unauthorized
    case 403:
      self = .forbidden
    case 404:
      self = .notFound
    case 409:
      self = .conflict
    default:
      self = .other
    }
  }

  public var rawValue: RawValue {
    switch self {
    case .ok: 200
    case .noContent: 204
    case .unauthorized: 401
    case .forbidden: 403
    case .notFound: 404
    case .conflict: 409
    case .other: -1
    }
  }
}
