// Copyright 2023 Yandex LLC. All rights reserved.

import Foundation

#if DEBUG
@usableFromInline
final class DebugInfo {
  @usableFromInline
  let callStack: [NSNumber]
  @usableFromInline
  let ancestors: [DebugInfo]

  public lazy var callStackSymbols: [String] = {
    let backtrace: [UnsafeMutableRawPointer?] = callStack
      .map { UnsafeMutableRawPointer(bitPattern: $0.intValue) }
    return backtrace.withUnsafeBufferPointer { bufferPointer in
      let symbolStrings: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>? = backtrace_symbols(
        bufferPointer.baseAddress!,
        Int32(bufferPointer.count)
      )
      defer {
        free(symbolStrings)
      }
      var symbols = [String]()
      if let symbolStrings {
        symbols = UnsafeBufferPointer(start: symbolStrings, count: backtrace.count).map {
          guard let symbol = $0 else {
            return "<null>"
          }
          return String(cString: symbol)
        }
      }
      return symbols
    }
  }()

  @inlinable
  public init(callStack: [NSNumber], ancestors: [DebugInfo]) {
    self.callStack = callStack
    self.ancestors = ancestors
  }
}

extension DebugInfo: CustomReflectable {
  public var customMirror: Mirror {
    Mirror(
      self,
      children: ["callStack": callStackSymbols, "ancestors": ancestors],
      displayStyle: .struct
    )
  }
}
#else
@usableFromInline
typealias DebugInfo = Void
#endif
