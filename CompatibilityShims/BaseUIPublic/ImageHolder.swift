import VGSLUI

public func ==(lhs: ImageHolder, rhs: ImageHolder) -> Bool {
  if lhs === rhs {
    return true
  }

  return lhs.equals(rhs)
}

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

public func !=(lhs: ImageHolder?, rhs: ImageHolder?) -> Bool {
  !(lhs == rhs)
}
