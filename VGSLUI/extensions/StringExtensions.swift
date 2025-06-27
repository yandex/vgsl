
import Foundation

extension String {
  public func with(typo: Typo) -> NSAttributedString {
    assert(typo.isHeightSufficient)

    return NSAttributedString(string: self, attributes: typo.attributes)
  }

  public func mutable(withTypo typo: Typo) -> NSMutableAttributedString {
    assert(typo.isHeightSufficient)

    return NSMutableAttributedString(string: self, attributes: typo.attributes)
  }
}
