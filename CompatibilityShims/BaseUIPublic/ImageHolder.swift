import VGSLUI

@preconcurrency @MainActor
public func ==(lhs: ImageHolder, rhs: ImageHolder) -> Bool {
  if lhs === rhs {
    return true
  }

  return lhs.equals(rhs)
}

@preconcurrency @MainActor
public func ==(lhs: ImageHolder?, rhs: ImageHolder?) -> Bool {
  switch (lhs, rhs) {
  case (.none, .none):
    true
  case let (.some(value1), .some(value2)):
    value1 == value2
  default:
    false
  }
}

@preconcurrency @MainActor
public func !=(lhs: ImageHolder?, rhs: ImageHolder?) -> Bool {
  !(lhs == rhs)
}
