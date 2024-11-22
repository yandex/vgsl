import Foundation

public enum PlaceholderEvent {
  case show(id: UUID)
  case hide(id: UUID)
}
