#
# Be sure to run `pod lib lint JYKit.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'JYKit'
  s.version          = '0.0.4'
  s.summary          = 'iOS 调试工具、Toast、二维码扫描等基础组件库。'

  s.description      = "JYKit 提供动态调试面板（悬浮球、性能监控、日志、文件、Keychain/UserDefaults、UI 层级、卡顿监控）、Toast 提示、二维码扫描，以及设备信息、消息转发、方法 hook 等底层工具，可按 subspec 按需接入。"

  s.homepage         = 'https://github.com/crazyball/JYKit'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'crazyball' => 'crazyball6666@gmail.com' }
  s.source           = { :git => 'https://github.com/crazyball/JYKit.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.swift_version = ['5.0']
  
  
  # 调试工具
  s.subspec 'DyTool' do |ss|
      ss.source_files = 'JYKit/DyTool/Classes/**/*.{h,m,swift}'
      ss.resources = 'JYKit/DyTool/Assets/SDKImages.bundle'
      ss.dependency 'JYKit/Tools'
      ss.dependency 'JYKit/HUD'
  end
  
  # Toast
  s.subspec 'HUD' do |ss|
      ss.source_files = 'JYKit/HUD/Classes/**/*'
  end
  
  # 扫码
  s.subspec 'QRCode' do |ss|
      ss.source_files = 'JYKit/QRCode/Classes/**/*'
  end
  
  # 工具库
  s.subspec 'Tools' do |ss|
      ss.source_files = 'JYKit/Tools/Classes/**/*'
  end
  
end
