Pod::Spec.new do |s|
  s.name             = 'VGSLBase'
  s.module_name      = 'BasePublic'
  s.version          = '6.16.2'
  s.summary          = 'Compatibility shims for VGSL'
  s.description      = 'Compatibility shims for VGSL'
  s.homepage         = 'https://github.com/yandex/vgsl'

  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'vgsl' => 'vgsl@yandex-team.ru' }
  s.source           = { :git => 'https://github.com/yandex/vgsl.git', :tag => s.version.to_s }

  s.swift_version = '5.9'
  s.requires_arc = true
  s.prefix_header_file = false
  s.platforms = { :ios => '12.0', :tvos => '12.0' }

  s.pod_target_xcconfig = {
    'OTHER_SWIFT_FLAGS' => '-enable-experimental-feature AccessLevelOnImport',
    'BUILD_LIBRARY_FOR_DISTRIBUTION' => 'NO'
  }
  
  s.dependency 'VGSLBaseUI', s.version.to_s
  s.dependency 'VGSLNetworkingPublic', s.version.to_s
  s.dependency 'VGSL', s.version.to_s

  s.source_files = [
    'CompatibilityShims/BasePublic/**/*'
  ]
end
