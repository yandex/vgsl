// Copyright 2021 Yandex LLC. All rights reserved.

#if canImport(UIKit)
import UIKit

#if !os(tvOS)
extension UIApplication: NetworkActivityIndicatorUI {}

@available(iOSApplicationExtension, unavailable)
@preconcurrency @MainActor
public let networkActivityIndicatorController = NetworkActivityIndicatorController(
  UI: UIApplication.shared
)
#endif

extension NetworkActivityIndicatorController {
  public static var stub: Self { Self(UI: NetworkActivityIndicatorStub()) }
}

private final class NetworkActivityIndicatorStub: NetworkActivityIndicatorUI {
  var isNetworkActivityIndicatorVisible = false
}
#endif
