// Copyright 2022 Yandex LLC. All rights reserved.

import Foundation

#if os(iOS)
extension NSKeyedArchiver {
  public class func legacyArchivedData(withRootObject object: Any) -> Data {
    (try? archivedData(withRootObject: object, requiringSecureCoding: false)) ?? Data()
  }
}
#endif
