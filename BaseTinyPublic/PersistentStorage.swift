// Copyright 2021 Yandex LLC. All rights reserved.

import Foundation

public protocol AsyncPersistentStorage {
  func readObject<T: Archivable>(
    forKey key: String,
    with classes: [AnyClass],
    completion: @escaping (T?, NSError?) -> Void
  )

  // Transferring nil as first object should remove it from storage
  func writeObject<T: Archivable>(
    _ object: T?,
    forKey key: String,
    completion: (() -> Void)?
  )
}

extension AsyncPersistentStorage {
  public func readObject<T: Archivable>(
    forKey key: String,
    completion: @escaping (T?) -> Void
  ) {
    readObject(forKey: key, with: []) { value, _ in completion(value) }
  }

  public func readObject(forKey key: String, completion: @escaping (Data?) -> Void) {
    readObject(forKey: key) { (data: NSData?) in completion(data as Data?) }
  }

  public func readObject(
    forKey key: String,
    completion: @escaping (Data?, NSError?) -> Void
  ) {
    readObject(forKey: key, with: []) { (data: NSData?, error: NSError?) in
      completion(data as Data?, error)
    }
  }

  public func writeObject(_ object: Data?, forKey key: String, completion: (() -> Void)?) {
    writeObject(object as NSData?, forKey: key, completion: completion)
  }
}

// Implementation of this class should provide fast access to load/store methods
// No long-term file operation or hard calculating is allowed here
public protocol SyncPersistentStorage: AnyObject {
  func object<T: Archivable>(forKey key: String, with classes: [AnyClass]) -> T?

  // Transferring nil as first object should remove it from storage
  func setObject<T: Archivable>(_ object: T?, forKey key: String)
}

extension SyncPersistentStorage {
  public func object<T: Archivable>(forKey key: String) -> T? {
    object(forKey: key, with: [
      NSDictionary.self,
      NSURL.self,
      NSSet.self,
      NSString.self,
      NSArray.self,
      NSNumber.self,
      NSData.self,
      NSDate.self,
      NSNull.self,
    ])
  }

  public subscript<T: Archivable>(key: String, _: T.Type = T.self) -> T? {
    get { object(forKey: key) }
    set { setObject(newValue, forKey: key) }
  }

  public subscript(key: String) -> Int? {
    get { self[key, NSNumber.self]?.intValue }
    set { self[key, NSNumber.self] = newValue.map(NSNumber.init) }
  }

  public subscript(key: String) -> Bool? {
    get { self[key, NSNumber.self]?.boolValue }
    set { self[key, NSNumber.self] = newValue.map(NSNumber.init) }
  }

  public subscript(key: String) -> String? {
    get { self[key, NSString.self] as String? }
    set { self[key, NSString.self] = newValue as NSString? }
  }

  public subscript(key: String) -> Date? {
    get { self[key, NSDate.self] as Date? }
    set { self[key, NSDate.self] = newValue as NSDate? }
  }
}
