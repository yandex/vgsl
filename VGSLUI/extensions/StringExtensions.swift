
import Foundation

extension String {
  public func with(typo: Typo) -> NSAttributedString {
    return NSAttributedString(string: self, attributes: typo.attributes)
  }

  public func mutable(withTypo typo: Typo) -> NSMutableAttributedString {
    return NSMutableAttributedString(string: self, attributes: typo.attributes)
  }
}
