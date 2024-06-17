// Copyright 2018 Yandex LLC. All rights reserved.

import Foundation

// swiftlint:disable use_make_instead_of_create

public protocol FileManaging {
  var applicationSupportDirectory: URL { get }
  var documentDirectory: URL { get }

  func fileExists(at url: URL) -> Bool
  func createFile(at url: URL, contents data: Data) throws
  func createFile(at url: URL, contents data: Data, options: Data.WritingOptions) throws
  func contents(at url: URL) throws -> Data
  func createDirectory(at url: URL, withIntermediateDirectories intermediates: Bool) throws
  func removeItem(at URL: URL) throws
  func moveItem(at srcURL: URL, to dstURL: URL) throws
}

extension FileManager: FileManaging {
  public var applicationSupportDirectory: URL {
    guard
      let applicationSupportDirectory =
      urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    else {
      assertionFailure("Unable to access application supportdirectory")
      // CommonCore is exported with minimal iOS version 9.0.
      // It's needed by RealTimeAnalytics pod, which is integrated in YXMobileMetrica.
      if #available(iOS 10, tvOS 10, *) {
        return temporaryDirectory
      } else {
        return URL(fileURLWithPath: NSTemporaryDirectory())
      }
    }

    return applicationSupportDirectory
  }

  public var documentDirectory: URL {
    guard
      let dir = urls(for: .documentDirectory, in: .userDomainMask).first
    else {
      assertionFailure("Unable to access documentDirectory")
      // CommonCore is exported with minimal iOS version 9.0.
      // It's needed by RealTimeAnalytics pod, which is integrated in YXMobileMetrica.
      if #available(iOS 10, tvOS 10, *) {
        return temporaryDirectory
      } else {
        return URL(fileURLWithPath: NSTemporaryDirectory())
      }
    }

    return dir
  }

  public func fileExists(at url: URL) -> Bool {
    fileExists(atPath: url.path)
  }

  public func contents(at url: URL) throws -> Data {
    try Data(contentsOf: url)
  }

  public func createFile(at url: URL, contents data: Data) throws {
    try data.write(to: url)
  }

  public func createFile(at url: URL, contents data: Data, options: Data.WritingOptions) throws {
    try data.write(to: url, options: options)
  }

  public func createDirectory(at url: URL, withIntermediateDirectories intermediates: Bool) throws {
    try createDirectory(
      atPath: url.path,
      withIntermediateDirectories: intermediates,
      attributes: nil
    )
  }
}

// swiftlint:enable use_make_instead_of_create
