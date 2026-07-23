// Copyright 2015 Yandex LLC. All rights reserved.

import Foundation

public typealias URLQueryParam = (name: String, value: String?)
public typealias URLQueryParams = [URLQueryParam]

extension URL {
  public func equalWithoutFragments(_ url: URL) -> Bool {
    if url == self {
      return true
    }

    if var components = URLComponents(url: self, resolvingAgainstBaseURL: false),
       var otherComponents = URLComponents(
         url: url,
         resolvingAgainstBaseURL: false
       ) {
      components.fragment = nil
      otherComponents.fragment = nil
      return components == otherComponents
    } else {
      // MOBYANDEXIOS-735
      //
      // As specified in RFC 3986, in "Parsing a URI Reference with a Regular Expression" part,
      // this expression could be used for parsing into components:
      // ^(([^:/?#]+):)?(//([^/?#]*))?([^?#]*)(\?([^#]*))?(#(.*))?
      //
      // Which means that symbol (#) could be used only to specify the fragment of the URL.
      // So, we can just crop the string up to this symbol to get the URL without fragment.

      return absoluteString.substring(until: "#") == url.absoluteString.substring(until: "#")
    }
  }

  public func queryParamValue(forName name: String) -> String? {
    queryItem(forName: name)?.value
  }

  public func queryItem(forName name: String) -> URLQueryItem? {
    queryItems?.first { $0.name == name }
  }

  public var queryParams: URLQueryParams {
    queryItems?.map { ($0.name, $0.value) } ?? []
  }

  public var queryItems: [URLQueryItem]? {
    URLComponents(url: self, resolvingAgainstBaseURL: false)?.queryItems
  }

  public var queryParamsDict: [String: String?] {
    Dictionary(queryParams.map { ($0.name, $0.value) }, uniquingKeysWith: { first, _ in first })
  }

  public var removingQuery: URL? {
    var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
    components?.query = nil
    return components?.url
  }

  public func removingQueryParameters(_ names: Set<String>) -> URL {
    guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
      assertionFailure("Failed to parse URL: \(absoluteString)")
      return self
    }
    components.queryItems = components.queryItems?.filter { !names.contains($0.name) }
    if let items = components.queryItems, items.isEmpty {
      components.query = nil
    }
    return components.url ?? self
  }

  public func removingQueryParameter(_ name: String) -> URL {
    removingQueryParameters([name])
  }

  public var isAppStoreURL: Bool {
    let components = URLComponents(url: self, resolvingAgainstBaseURL: false)

    guard let scheme = components?.scheme, let host = components?.host else {
      return false
    }

    return scheme.hasPrefix("itms")
      || host.hasSuffix("itunes.apple.com")
      || host.hasSuffix("apps.apple.com")
  }

  public var isHypertextURL: Bool {
    let lowercased = scheme?.lowercased()
    return lowercased == "http" || lowercased == "https"
  }

  public var isBlobURL: Bool {
    scheme?.lowercased() == "blob"
  }

  public func addingDefaultScheme(_ newScheme: String) -> URL {
    guard (scheme ?? "").isEmpty else {
      return self
    }
    guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
      assertionFailure("Failed to parse URL: \(absoluteString)")
      return self
    }
    components.scheme = newScheme
    return components.url ?? self
  }

  public var domains: [String]? {
    // in file://some/path `some` is also defined as "host"
    // https://tools.ietf.org/html/rfc1738#section-3.10
    guard !isFileURL else { return nil }
    return host?.components(separatedBy: ".")
  }

  public var hostAndPathString: String? {
    guard !isFileURL, let host else { return nil }
    return host + (path == "/" ? "" : path)
  }

  /// Returns the URL with scheme, authority (user, password, host, port) removed,
  /// leaving only the path, query, and fragment.
  public var removingAuthority: URL? {
    modified(components) {
      $0?.user = nil
      $0?.password = nil
      $0?.host = nil
      $0?.scheme = nil
      $0?.port = nil
    }?.url
  }

  public var origin: URL {
    var components = URLComponents()
    components.scheme = scheme
    components.host = host
    components.port = port
    guard let url = components.url else {
      assertionFailure()
      return URL(string: "brokenurl:")!
    }
    return url
  }

  public var components: URLComponents? {
    URLComponents(url: self, resolvingAgainstBaseURL: false)
  }

  public static func mailToURL(_ email: String, subject: String?, body: String?) -> URL? {
    var params = [String: String]()

    if let subject {
      params["subject"] = subject
    }

    if let body {
      params["body"] = body
    }

    return URL(string: "mailto:\(email)")?.upsertingQueryParams(params)
  }

  /// Inserts new query parameters or updates existing ones (upsert),
  /// preserving the order of existing params (matched names are replaced in place)
  /// and appending unmatched new params in the caller-provided order.
  public func upsertingQueryParams(_ params: URLQueryParams) -> URL {
    guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
      assertionFailure("Failed to parse URL: \(absoluteString)")
      return self
    }
    let currentParams: URLQueryParams = components.queryItems?.map { ($0.name, $0.value) } ?? []
    var paramsByName: [String: String?] = [:]
    for param in params {
      paramsByName[param.name] = param.value
    }
    var existingNames = Set<String>()
    let updatedExisting: URLQueryParams = currentParams.map { name, value in
      existingNames.insert(name)
      if let newValue = paramsByName[name] {
        return (name, newValue)
      }
      return (name, value)
    }
    let appendedParams = params.filter { !existingNames.contains($0.name) }
    let encodedQueryItems = (updatedExisting + appendedParams).map { name, value -> String in
      String(forQueryItemWithName: name, value: value)
    }
    components.percentEncodedQuery = encodedQueryItems.isEmpty ? nil : encodedQueryItems
      .joined(separator: "&")
    return components.url ?? self
  }

  /// Inserts new query parameters or updates existing ones (upsert) from a dictionary.
  /// Parameters are sorted by name for deterministic output since dictionaries have no order.
  public func upsertingQueryParams(_ params: [String: String]) -> URL {
    upsertingQueryParams(params.queryParams.sorted { $0.name < $1.name })
  }

  public func replacingScheme(with newScheme: String) -> URL {
    guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
      assertionFailure("Failed to parse URL: \(absoluteString)")
      return self
    }
    components.scheme = newScheme
    return components.url ?? self
  }

  public var basePartOnly: URL {
    guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
      assertionFailure("Failed to parse URL: \(absoluteString)")
      return self
    }
    components.path = ""
    components.query = nil
    components.fragment = nil
    guard let url = components.url else {
      assertionFailure("Failed to compose URL: \(absoluteString)")
      return self
    }
    return url
  }

  /// Creates a relative link with specified base URL and relative part calculated by removing
  /// base URL components from the front.
  /// If specified URL is not prefixed by base URL - it is simply ignored.
  public static func resolveFileURL(_ url: URL, againstURL baseURL: URL) throws -> URL {
    guard url.isFileURL, baseURL.isFileURL else {
      throw FileURLError.notAFileURL
    }

    // ensure base url is a directory url
    let basePath = modified(baseURL.path) {
      if !$0.hasSuffix("/") { $0 += "/" }
    }
    let baseDirURL = URL(fileURLWithPath: basePath, isDirectory: true)

    guard url != baseURL else { return URL(fileURLWithPath: ".", relativeTo: baseDirURL) }

    guard url.path.hasPrefix(basePath) else { return url }

    let relativePath = String(url.path[basePath.endIndex...])
    return URL(fileURLWithPath: relativePath, relativeTo: baseDirURL)
  }
}

extension URLQueryParams {
  public func filteringNilValues() -> URLQueryParams {
    filter { $0.value != nil }
  }
}

public enum FileURLError: Swift.Error {
  case notAFileURL
}

// MARK: - Deprecated

extension URL {
  @available(*, deprecated, renamed: "removingQuery")
  public var URLByStrippingQuery: URL? { removingQuery }

  @available(*, deprecated, renamed: "addingDefaultScheme(_:)")
  public func URLWithDefaultScheme(_ defaultScheme: String) -> URL {
    addingDefaultScheme(defaultScheme)
  }

  @available(*, deprecated, renamed: "removingAuthority")
  public var sanitizedHost: URL? { removingAuthority }

  @available(*, deprecated, renamed: "upsertingQueryParams(_:)")
  public func URLByAddingGETParameters(_ params: URLQueryParams) -> URL {
    var components = URLComponents(url: self, resolvingAgainstBaseURL: false)!
    var currentParams: URLQueryParams = components.queryItems?.map { ($0.name, $0.value) } ?? []
    let overriddenNames = params.map(\.name)
    currentParams = currentParams.filter { !overriddenNames.contains($0.name) }
    let encodedQueryItems = (currentParams + params).map { name, value -> String in
      String(forQueryItemWithName: name, value: value)
    }
    components.percentEncodedQuery = encodedQueryItems.isEmpty ? nil : encodedQueryItems.sorted()
      .joined(separator: "&")
    return components.url!
  }

  @available(*, deprecated, renamed: "upsertingQueryParams(_:)")
  public func URLByAddingGETParameters(_ params: [String: String]) -> URL {
    URLByAddingGETParameters(params.queryParams)
  }

  @available(*, deprecated, renamed: "replacingScheme(with:)")
  public func URLByReplacingScheme(_ scheme: String) -> URL {
    replacingScheme(with: scheme)
  }
}
