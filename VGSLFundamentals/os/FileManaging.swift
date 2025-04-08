// Copyright 2018 Yandex LLC. All rights reserved.

import Foundation

// swiftlint:disable use_make_instead_of_create

public protocol FileManaging {
  var applicationSupportDirectory: URL { get }
  var documentDirectory: URL { get }
  var libraryDirectory: URL { get }
  var temporaryDirectory: URL { get }

  func fileExists(at url: URL) -> Bool
  func createFile(at url: URL, contents data: Data) throws
  func createFile(at url: URL, contents data: Data, options: Data.WritingOptions) throws
  func contents(at url: URL) throws -> Data
  func createDirectory(at url: URL, withIntermediateDirectories intermediates: Bool) throws
  func removeItem(at url: URL) throws
  func moveItem(at srcURL: URL, to dstURL: URL) throws
}

extension FileManager: FileManaging {
  public func createDirectory(at url: URL, withIntermediateDirectories intermediates: Bool) throws {
    try createDirectory(
      atPath: url.path,
      withIntermediateDirectories: intermediates,
      attributes: nil
    )
  }

  public var applicationSupportDirectory: URL {
    getSystemDirectoryURL(.applicationSupportDirectory)
  }

  public var documentDirectory: URL {
    getSystemDirectoryURL(.documentDirectory)
  }

  public var libraryDirectory: URL {
    getSystemDirectoryURL(.libraryDirectory)
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

  private func getSystemDirectoryURL(_ directory: FileManager.SearchPathDirectory) -> URL {
    guard let dir = urls(for: directory, in: .userDomainMask).first else {
      assertionFailure("Unable to access \(directory)")
      return temporaryDirectory
    }
    return dir
  }
}

// swiftlint:enable use_make_instead_of_create
