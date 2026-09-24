// Copyright 2026 Yandex LLC. All rights reserved.

public enum TextTruncationPolicy: Hashable, Sendable {
  /// Truncates at the last typographic cluster that fits.
  case grapheme
  /// Prefers the last Unicode line-break boundary that fits.
  case word
}
