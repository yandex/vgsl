// Copyright 2017 Yandex LLC. All rights reserved.

import Foundation

// Exported with minimal iOS version 9.0.
@available(iOS 10, tvOS 10, *)
extension URLSessionTaskMetrics {
  var networkSessionMetrics: [NetworkSessionMetrics] {
    transactionMetrics
  }
}

// Exported with minimal iOS version 9.0.
@available(iOS 10, tvOS 10, *)
extension URLSessionTaskTransactionMetrics: NetworkSessionMetrics {}
