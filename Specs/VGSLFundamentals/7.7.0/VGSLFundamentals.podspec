Pod::Spec.new do |s|
  s.name             = 'VGSLFundamentals'
  s.module_name      = 'VGSLFundamentals'
  s.version          = '7.7.0'
  s.summary          = 'A useful set of basic components for an iOS app'
  s.description      = 'A useful set of basic components for an iOS app'
  s.homepage         = 'https://github.com/yandex/vgsl'

  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'vgsl' => 'vgsl@yandex-team.ru' }
  s.source           = { :git => 'https://github.com/yandex/vgsl.git', :tag => s.version.to_s }

  s.swift_version = '5.9'
  s.requires_arc = true
  s.prefix_header_file = false
  s.platforms = { :ios => '13.0', :tvos => '13.0' }

  s.pod_target_xcconfig = {
    'OTHER_SWIFT_FLAGS' => '-enable-experimental-feature AccessLevelOnImport',
    'BUILD_LIBRARY_FOR_DISTRIBUTION' => 'NO'
  }

  s.source_files = [
    'VGSLFundamentals/**/*.swift'
  ]

  s.resource_bundles = {
    'VGSLFundamentalsPrivacyInfo' => ['VGSLFundamentals/PrivacyInfo.xcprivacy']
  }
  
end
