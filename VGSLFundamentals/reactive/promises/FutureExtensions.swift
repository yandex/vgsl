// Copyright 2024 Yandex LLC. All rights reserved.

extension Future where T: Sendable {
  @available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
  public var value: T {
    get async {
      // TODO(pavor): IBRO-47926. Put back `withCheckedContinuation` when userbase
      // of iOS 18 beta is reduced below threshold.
      await withUnsafeContinuation { continuation in
        resolved { value in
          continuation.resume(returning: value)
        }
      }
    }
  }
}
