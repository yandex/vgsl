// Copyright 2017 Yandex LLC. All rights reserved.

import Foundation

public let MainQueue: SerialOperationQueue = MainQueueProxy()

// swiftlint:disable no_direct_use_for_main_queue
private let systemMainQueue = OperationQueue.main
// swiftlint:enable no_direct_use_for_main_queue

private class MainQueueProxy: SerialOperationQueue {
  func addOperation(_ operation: Operation) {
    assert(!operation.isAsynchronous)
    systemMainQueue.addOperation(operation)
  }

  func addOperation(_ block: @escaping () -> Void) {
    systemMainQueue.addOperation(block)
  }

  func cancelAllOperations() {
    systemMainQueue.cancelAllOperations()
  }

  var maxConcurrentOperationCount: Int {
    get {
      systemMainQueue.maxConcurrentOperationCount
    }

    set {
      assert(newValue == 1)
      systemMainQueue.maxConcurrentOperationCount = newValue
    }
  }
}
