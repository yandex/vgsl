Pod::Spec.new do |s|
  s.name             = 'VGSLBaseUI'
  s.module_name      = 'BaseUIPublic'
  s.version          = '5.1.1'
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

  s.source_files = [
    'BaseUIPublic/**/*'
  ]
end
