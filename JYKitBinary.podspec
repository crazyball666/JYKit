Pod::Spec.new do |s|
  s.name             = 'JYKitBinary'
  s.version          = '0.0.1'
  s.summary          = 'Binary distribution for JYKit.'

  s.description      = 'Prebuilt XCFramework distribution for JYKit.'

  s.homepage         = 'https://github.com/crazyball666/JYKit'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'crazyball' => 'crazyball6666@gmail.com' }
  s.source           = { :http => "https://github.com/crazyball666/JYKit/releases/download/v#{s.version}/JYKit.xcframework.zip" }

  s.ios.deployment_target = '11.0'
  s.swift_version = '5.0'
  s.vendored_frameworks = 'JYKit.xcframework'
end
