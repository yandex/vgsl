// Copyright 2022 Yandex LLC. All rights reserved.

import Foundation

#if os(iOS)
extension NSKeyedUnarchiver {
  public class func legacyUnarchiveObject(with data: Data) -> Any? {
    try? unarchivedObject(ofClasses: [AnyObject.self], from: data)
  }
}
#endif
