// Copyright 2018 Yandex LLC. All rights reserved.

#if os(iOS) || os(tvOS)
import QuartzCore.CATransaction

extension CATransaction {
  public static func performWithoutAnimations(_ block: () -> Void) {
    let isActionsDisabled = disableActions()
    setDisableActions(true)
    block()
    setDisableActions(isActionsDisabled)
  }
}
#endif
