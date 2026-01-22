
import Foundation

extension String {
  public func with(typo: Typo) -> NSAttributedString {
    NSAttributedString(string: self, attributes: typo.attributes)
  }

  public func mutable(withTypo typo: Typo) -> NSMutableAttributedString {
    NSMutableAttributedString(string: self, attributes: typo.attributes)
  }
}
