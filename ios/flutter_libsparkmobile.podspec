#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_libsparkmobile.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_libsparkmobile'
  s.version          = '0.0.1'
  s.summary          = 'A new Flutter project.'
  s.description      = <<-DESC
A new Flutter project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }

  s.source           = { :path => '.' }
  s.prepare_command = <<-CMD
    "./run_build.sh"
  CMD
  # Use XCFramework to support both device and simulator (arm64 for both)
  # XCFramework is required because we can't combine device and simulator arm64 with lipo
  # Note: CocoaPods should automatically extract the appropriate slice, but Flutter's build
  # system may need the framework search path to point directly to the XCFramework
  s.vendored_frameworks = 'flutter_libsparkmobile.xcframework'
  s.dependency 'Flutter'
  s.platform = :ios, '11.0'

  # Flutter.framework does not contain a i386 slice.
  # Exclude x86_64 since we only build arm64 for simulator (Apple Silicon Macs)
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386 x86_64',
    'ONLY_ACTIVE_ARCH' => 'YES'
  }
  s.user_target_xcconfig = {
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386 x86_64'
  }
  s.swift_version = '5.0'
end
