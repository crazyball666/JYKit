# JYKit

[![Release Binary Framework](https://github.com/crazyball666/JYKit/actions/workflows/release-binary.yml/badge.svg)](https://github.com/crazyball666/JYKit/actions/workflows/release-binary.yml)
[![Latest Release](https://img.shields.io/github/v/release/crazyball666/JYKit)](https://github.com/crazyball666/JYKit/releases)
[![License](https://img.shields.io/github/license/crazyball666/JYKit)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-iOS-lightgrey)](#环境要求)

JYKit 是一个 iOS 工具库，主要包含动态调试工具、Toast/HUD、二维码扫描、运行时工具和设备信息能力。

其中 `DyTool` 的定位是动态调试插件：接入后会通过 `+load` 自动启动，并保留日志 hook、悬浮球、性能悬浮窗等能力，方便在调试包或内部包里动态注入和现场排查问题。

## 功能模块

| 模块 | 说明 |
| --- | --- |
| `DyTool` | 调试浮窗、悬浮性能监控、日志 hook、文件管理、Keychain/UserDefaults 管理、UI 层级查看、卡顿监控 |
| `HUD` | Toast 和轻量提示 UI |
| `QRCode` | 相机扫码、相册选图识别、二维码扫描 UI |
| `Tools` | 设备信息、运行时消息转发、方法 hook 等底层工具 |

## 环境要求

- iOS 11.0+
- Swift 5
- CocoaPods

## 安装

### 二进制方式

推荐业务项目直接使用 Release 产物，省去本地编译源码的时间：

```ruby
pod 'JYKitBinary', :podspec => 'https://github.com/crazyball666/JYKit/releases/download/v0.0.2/JYKitBinary.podspec'
```

二进制包内包含 `JYKit.xcframework`，Swift/Objective-C 模块名仍然是 `JYKit`：

```swift
import JYKit
```

注意：`JYKitBinary` 当前是完整包，包含 `DyTool` 动态调试能力。`DyTool` 会自动启动悬浮球和日志 hook，请确认它符合你的包类型和使用场景。

### 源码方式

如果需要本地调试源码，或者只想集成某个子模块，可以使用源码 pod：

```ruby
pod 'JYKit', :git => 'https://github.com/crazyball666/JYKit.git', :branch => 'main'
```

只接入某个 subspec：

```ruby
pod 'JYKit/HUD', :git => 'https://github.com/crazyball666/JYKit.git', :branch => 'main'
pod 'JYKit/QRCode', :git => 'https://github.com/crazyball666/JYKit.git', :branch => 'main'
pod 'JYKit/DyTool', :git => 'https://github.com/crazyball666/JYKit.git', :branch => 'main'
```

`DyTool` 依赖 `Tools` 和 `HUD`，单独接入 `JYKit/DyTool` 时 CocoaPods 会自动拉取依赖。

## 快速使用

### DyTool

接入 `DyTool` 后无需手动初始化，`Loader` 会在 `+load` 阶段自动调用：

```swift
DynamicTools.setup()
```

默认行为：

- 启动日志 hook。
- 启动卡顿监控。
- App 启动约 2 秒后展示悬浮球。
- 摇一摇也会重新展示悬浮球。

如果需要手动展示悬浮球：

```swift
DynamicTools.showBall()
```

自定义卡顿监控：

```swift
DynamicTools.setLagMonitorEnabled(true)
DynamicTools.setLagMonitorThresholdMilliseconds(500)
```

### HUD

```swift
JYToast.show("操作成功")
```

### QRCode

二维码模块提供相机扫码和相册选图能力，具体用法可以参考 `Example/JYKit` 里的示例页面。

## 本地开发

```bash
git clone https://github.com/crazyball666/JYKit.git
cd JYKit/Example
pod install
open JYKit.xcworkspace
```

常用验证命令：

```bash
xcodebuild build -workspace Example/JYKit.xcworkspace -scheme JYKit-Example -sdk iphonesimulator
```

## 发布二进制版本

项目已经配置 GitHub Actions。推送 `v*` tag 后，会自动构建并发布 `JYKit.xcframework`：

```bash
git tag v0.0.3
git push origin v0.0.3
```

发布流程会自动完成：

1. 构建真机和模拟器 archive。
2. 合成 `JYKit.xcframework`。
3. 打包 `JYKit.xcframework.zip`。
4. 生成带 `sha256` 的 `JYKitBinary.podspec`。
5. 创建 GitHub Release 并上传产物。

发布完成后，使用对应版本的 podspec URL 即可：

```ruby
pod 'JYKitBinary', :podspec => 'https://github.com/crazyball666/JYKit/releases/download/v0.0.3/JYKitBinary.podspec'
```

## License

JYKit 基于 MIT License 开源，详情见 [LICENSE](LICENSE)。
