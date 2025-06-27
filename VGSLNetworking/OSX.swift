// Copyright 2021 Yandex LLC. All rights reserved.

#if os(macOS)
import AppKit

private final class NetworkActivityIndicator: NetworkActivityIndicatorUI {
  var isNetworkActivityIndicatorVisible = false
}

extension NetworkActivityIndicatorController {
  public static var stub: Self { Self(UI: NetworkActivityIndicator()) }
}

@preconcurrency @MainActor
public let networkActivityIndicatorController =
  NetworkActivityIndicatorController.stub
#endif
