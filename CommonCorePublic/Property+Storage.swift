// Copyright 2020 Yandex LLC. All rights reserved.

import Foundation

extension Property where T: Codable {
  public init(
    fileName: String,
    initialValue: T,
    onError: @escaping (Error) -> Void
  ) {
    let fileManager = FileManager.default
    let fileURL = Lazy<URL>(getter: {
      fileManager
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)
        .first!
        .appendingPathComponent(fileName)
    })

    var value: T?
    self.init(
      getter: {
        if let currentValue = value {
          return currentValue
        }
        let storedValue: T? =
          if fileManager.fileExists(atPath: fileURL.value.path) {
            read(url: fileURL.value, onError: onError)
          } else {
            nil
          }
        let currentValue = storedValue ?? initialValue
        value = currentValue
        return currentValue
      },
      setter: {
        value = $0
        write($0, url: fileURL.value, onError: onError)
      }
    )
  }
}

private func read<T: Decodable>(url: URL, onError: (Error) -> Void) -> T? {
  do {
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(T.self, from: data)
  } catch {
    onError(error)
    return nil
  }
}

private func write(_ value: some Encodable, url: URL, onError: (Error) -> Void) {
  do {
    let newData = try JSONEncoder().encode(value)
    try newData.write(to: url, options: .atomicWrite)
  } catch {
    onError(error)
  }
}
