Pod::Spec.new do |s|
  s.name             = 'VGSLBase'
  s.module_name      = 'BasePublic'
  s.version          = '5.1.0'
  s.summary          = 'A useful set of basic components for an iOS app'
  s.description      = 'A useful set of basic components for an iOS app'
  s.homepage         = 'https://github.com/yandex/vgsl'

  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'vgsl' => 'vgsl@yandex-team.ru' }
  s.source           = { :git => 'https://github.com/yandex/vgsl.git', :tag => s.version.to_s }

  s.swift_version = '5.9'
  s.requires_arc = true
  s.prefix_header_file = false
  s.platforms = { :ios => '9.0', :tvos => '9.0' }
  
  s.dependency 'VGSLBaseTiny', s.version.to_s
  s.dependency 'VGSLBaseUI', s.version.to_s
  s.dependency 'VGSL_Fundamentals', s.version.to_s

  s.source_files = [
    'BasePublic/**/*'
  ]

  s.resource_bundles = {
    'BasePublicPrivacyInfo' => ['BasePublic/PrivacyInfo.xcprivacy'],
  }
end
