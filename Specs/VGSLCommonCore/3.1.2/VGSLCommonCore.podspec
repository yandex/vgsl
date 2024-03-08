Pod::Spec.new do |s|
  s.name             = 'VGSLCommonCore'
  s.module_name      = 'CommonCorePublic'
  s.version          = '3.1.2'
  s.summary          = 'A useful set of basic components for an iOS app'
  s.description      = 'A useful set of basic components for an iOS app'
  s.homepage         = 'https://github.com/yandex/vgsl'

  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'vgsl' => 'vgsl@yandex-team.ru' }
  s.source           = { :git => 'https://github.com/yandex/vgsl.git', :tag => s.version.to_s }

  s.swift_version = '5.9'
  s.requires_arc = true
  s.prefix_header_file = false
  s.platforms = { :ios => '9.0', :tvos => '12.0' }

  s.dependency 'VGSLBase', s.version.to_s

  s.source_files = [
    'CommonCorePublic/**/*'
  ]
end
