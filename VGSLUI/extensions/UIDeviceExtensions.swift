// Copyright 2023 Yandex LLC. All rights reserved.

#if canImport(UIKit)
import CoreHaptics
import UIKit

extension UIDevice {
  public enum SafeAreaKind: String, Codable {
    case dynamicIsland
    case notch
    case none
  }

  public var systemModelName: String {
    #if !targetEnvironment(simulator)
    var systemInfo = utsname()
    uname(&systemInfo)
    let identifier = withUnsafePointer(to: &systemInfo.machine) {
      $0.withMemoryRebound(to: CChar.self, capacity: 1) { ptr in
        #if swift(>=6.0)
        String(validatingCString: ptr)
        #else
        String(validatingUTF8: ptr)
        #endif
      }
    }
    #else
    let identifier = ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"]
    #endif
    assert(identifier != nil)
    return identifier ?? "undefined_model"
  }

  // https://gist.github.com/adamawolf/3048717
  @objc public var humanReadableModel: String {
    let name = systemModelName
    switch name {
    case "iPhone1,1": return "iPhone"
    case "iPhone1,2": return "iPhone 3G"
    case "iPhone2,1": return "iPhone 3GS"
    case "iPhone3,1": return "iPhone 4"
    case "iPhone3,2", "iPhone3,3": return "iPhone 4"
    case "iPhone4,1": return "iPhone 4S"
    case "iPhone5,1", "iPhone5,2": return "iPhone 5"
    case "iPhone5,3", "iPhone5,4": return "iPhone 5C"
    case "iPhone6,1", "iPhone6,2": return "iPhone 5S"
    case "iPhone7,1": return "iPhone 6 Plus"
    case "iPhone7,2": return "iPhone 6"
    case "iPhone8,1": return "iPhone 6s"
    case "iPhone8,2": return "iPhone 6s Plus"
    case "iPhone8,4": return "iPhone SE"
    case "iPhone9,1", "iPhone9,3": return "iPhone 7"
    case "iPhone9,2", "iPhone9,4": return "iPhone 7 Plus"
    case "iPhone10,1", "iPhone10,4": return "iPhone 8"
    case "iPhone10,2", "iPhone10,5": return "iPhone 8 Plus"
    case "iPhone10,3", "iPhone10,6": return "iPhone X"
    case "iPhone11,2": return "iPhone XS"
    case "iPhone11,4", "iPhone11,6": return "iPhone XS Max"
    case "iPhone11,8": return "iPhone XR"
    case "iPhone12,1": return "iPhone 11"
    case "iPhone12,3": return "iPhone 11 Pro"
    case "iPhone12,5": return "iPhone 11 Pro Max"
    case "iPhone12,8": return "iPhone SE 2"
    case "iPhone13,1": return "iPhone 12 Mini"
    case "iPhone13,2": return "iPhone 12"
    case "iPhone13,3": return "iPhone 12 Pro"
    case "iPhone13,4": return "iPhone 12 Pro Max"
    case "iPhone14,2": return "iPhone 13 Pro"
    case "iPhone14,3": return "iPhone 13 Pro Max"
    case "iPhone14,4": return "iPhone 13 Mini"
    case "iPhone14,5": return "iPhone 13"
    case "iPhone14,6": return "iPhone SE 3"
    case "iPhone14,7": return "iPhone 14"
    case "iPhone14,8": return "iPhone 14 Plus"
    case "iPhone15,2": return "iPhone 14 Pro"
    case "iPhone15,3": return "iPhone 14 Pro Max"
    case "iPhone15,4": return "iPhone 15"
    case "iPhone15,5": return "iPhone 15 Plus"
    case "iPhone16,1": return "iPhone 15 Pro"
    case "iPhone16,2": return "iPhone 15 Pro Max"
    case "iPhone17,1": return "iPhone 16 Pro"
    case "iPhone17,2": return "iPhone 16 Pro Max"
    case "iPhone17,3": return "iPhone 16"
    case "iPhone17,4": return "iPhone 16 Plus"
    case "iPhone17,5": return "iPhone 16e"
    case "iPhone18,1": return "iPhone 17 Pro"
    case "iPhone18,2": return "iPhone 17 Pro Max"
    case "iPhone18,3": return "iPhone 17"
    case "iPhone18,4": return "iPhone Air"
    case "iPad1,1", "iPad1,2": return "iPad"
    case "iPad2,1", "iPad2,2", "iPad2,3", "iPad2,4": return "iPad 2"
    case "iPad3,1", "iPad3,2", "iPad3,3": return "iPad 3"
    case "iPad2,5", "iPad2,6", "iPad2,7": return "iPad mini"
    case "iPad3,4", "iPad3,5", "iPad3,6": return "iPad 4"
    case "iPad4,1", "iPad4,2", "iPad4,3": return "iPad Air"
    case "iPad4,4", "iPad4,5", "iPad4,6": return "iPad mini Retina"
    case "iPad4,7", "iPad4,8", "iPad4,9": return "iPad Mini 3"
    case "iPad5,1", "iPad5,2": return "iPad mini 4"
    case "iPad5,3", "iPad5,4": return "iPad Air 2"
    case "iPad6,3", "iPad6,4": return "iPad Pro 9.7\""
    case "iPad6,7", "iPad6,8": return "iPad Pro 12.9\""
    case "iPad6,11", "iPad6,12": return "iPad 5"
    case "iPad7,1", "iPad7,2": return "iPad Pro 2"
    case "iPad7,3": return "iPad Pro"
    case "iPad7,4": return "iPad Pro"
    case "iPad7,5", "iPad7,6": return "iPad 6"
    case "iPad7,11", "iPad7,12": return "iPad 7th Gen 10.2\""
    case "iPad8,1", "iPad8,2", "iPad8,3", "iPad8,4": return "iPad Pro 3 11\""
    case "iPad8,5", "iPad8,6", "iPad8,7", "iPad8,8": return "iPad Pro 3 12.9\""
    case "iPad8,9", "iPad8,10": return "iPad Pro 4 11\""
    case "iPad8,11", "iPad8,12": return "iPad Pro 4 12.9\""
    case "iPad11,1", "iPad11,2": return "iPad mini 5"
    case "iPad11,3", "iPad11,4": return "iPad Air 3"
    case "iPad11,6", "iPad11,7": return "iPad 8"
    case "iPad12,1", "iPad12,2": return "iPad 9"
    case "iPad14,1", "iPad14,2": return "iPad mini 6"
    case "iPad13,1", "iPad13,2": return "iPad Air 4"
    case "iPad13,4", "iPad13,5", "iPad13,6", "iPad13,7": return "iPad Pro 5 11\""
    case "iPad13,8", "iPad13,9", "iPad13,10", "iPad13,11": return "iPad Pro 5 12.9\""
    case "iPad13,16", "iPad13,17": return "iPad Air 5"
    case "iPad13,18", "iPad13,19": return "iPad 10"
    case "iPad14,3-A", "iPad14,3-B", "iPad14,4-A", "iPad14,4-B", "iPad14,3", "iPad14,4":
      return "iPad Pro 4 11\""
    case "iPad14,5-A", "iPad14,5-B", "iPad14,6-A", "iPad14,6-B", "iPad14,5", "iPad14,6":
      return "iPad Pro 6 12.9\""
    case "iPad14,8", "iPad14,9": return "iPad Air 11\" (M2)"
    case "iPad14,10", "iPad14,11": return "iPad Air 13\" (M2)"
    case "iPad15,3", "iPad15,4": return "iPad Air 11\" (M3)"
    case "iPad15,5", "iPad15,6": return "iPad Air 13\" (M3)"
    case "iPad15,7", "iPad15,8": return "iPad (A16)"
    case "iPad16,1", "iPad16,2": return "iPad mini (A17 Pro)"
    case "iPad16,3", "iPad16,4": return "iPad Pro 11\" (M4)"
    case "iPad16,5", "iPad16,6": return "iPad Pro 13\" (M4)"
    default:
      assertionFailure()
      return model
    }
  }

  @available(iOS 13.0, *)
  @available(tvOS 14.0, *)
  public var isHapticEngineAvailable: Bool {
    CHHapticEngine.capabilitiesForHardware().supportsHaptics
  }
}
#endif
