#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
#
Pod::Spec.new do |s|
  s.name             = 'masterfabric_app_icon'
  s.version          = '0.0.1'
  s.summary          = 'A Flutter plugin for changing app icons dynamically.'
  s.description      = <<-DESC
A Flutter plugin that allows you to change your app icon dynamically at runtime.
Supports up to 4 alternative icons with date-based scheduling and network triggers.
                       DESC
  s.homepage         = 'https://github.com/masterfabric/masterfabric_app_icon'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Masterfabric' => 'info@masterfabric.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.platform         = :osx, '10.14'
  s.swift_version    = '5.0'
end
