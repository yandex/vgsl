// Copyright 2024 Yandex LLC. All rights reserved.

extension Future where T: Sendable {
  @available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
  public var value: T {
    get async {
      await withCheckedContinuation { continuation in
        resolved { value in
          continuation.resume(returning: value)
        }
      }
    }
  }
}
