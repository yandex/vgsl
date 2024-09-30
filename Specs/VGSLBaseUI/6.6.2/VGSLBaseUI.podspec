Pod::Spec.new do |s|
  s.name             = 'VGSLBaseUI'
  s.module_name      = 'BaseUIPublic'
  s.version          = '6.6.2'
  s.summary          = 'Compatibility shims for VGSL'
  s.description      = 'Compatibility shims for VGSL'
  s.homepage         = 'https://github.com/yandex/vgsl'

  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'vgsl' => 'vgsl@yandex-team.ru' }
  s.source           = { :git => 'https://github.com/yandex/vgsl.git', :tag => s.version.to_s }

  s.swift_version = '5.9'
  s.requires_arc = true
  s.prefix_header_file = false
  s.platforms = { :ios => '9.0', :tvos => '9.0' }

  s.pod_target_xcconfig = {
    'OTHER_SWIFT_FLAGS' => '-enable-experimental-feature AccessLevelOnImport'
  }
  
  s.dependency 'VGSL', s.version.to_s

  s.source_files = [
    'CompatibilityShims/BaseUIPublic/**/*'
  ]
end
