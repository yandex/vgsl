// Copyright 2022 Yandex LLC. All rights reserved.

import UIKit

import VGSLFundamentals

public final class RemoteImageViewContainer: UIView {
  private var backgroundModel: ImageViewBackgroundModel? {
    didSet {
      backgroundModel.applyTo(self, oldValue: oldValue)
    }
  }

  public var contentView: RemoteImageViewContentProtocol {
    didSet {
      guard contentView !== oldValue else { return }
      oldValue.removeFromSuperview()
      addSubview(contentView)
    }
  }

  var imageRequest: Cancellable?
  public var imageHolder: ImageHolder? {
    set {
      setImageHolder(newValue) {}
    }
    get {
      _imageHolder
    }
  }

  public func setImageHolder(_ imageHolder: ImageHolder?, completion: @escaping Action) {
    _imageHolder = imageHolder
    imageHolderUpdated(completion: completion)
  }

  private var _imageHolder: ImageHolder?

  private func imageHolderUpdated(completion: @escaping Action) {
    imageRequest?.cancel()
    contentView.setImage(nil, animated: false)
    backgroundModel = imageHolder?.placeholder.flatMap(ImageViewBackgroundModel.init)

    let newValue = imageHolder
    imageRequest = imageHolder?.requestImageWithSource { [weak self] result in
      guard let self,
            newValue === self.imageHolder else {
        completion()
        return
      }

      self.contentView.setImage(result?.0, animated: result?.1.shouldAnimate)
      self.backgroundModel = nil
      completion()
    }
  }

  public init(contentView: RemoteImageViewContentProtocol = RemoteImageView()) {
    self.contentView = contentView
    super.init(frame: .zero)
    addSubview(contentView)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public override func layoutSubviews() {
    super.layoutSubviews()
    contentView.frame = bounds
    backgroundModel?.view?.frame = bounds
  }

  deinit {
    imageRequest?.cancel()
  }
}
