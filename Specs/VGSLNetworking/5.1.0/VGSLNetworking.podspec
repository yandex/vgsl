Pod::Spec.new do |s|
  s.name             = 'VGSLNetworking'
  s.module_name      = 'NetworkingPublic'
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

  s.dependency 'VGSLBase', s.version.to_s

  s.source_files = [
    'NetworkingPublic/**/*'
  ]
end
