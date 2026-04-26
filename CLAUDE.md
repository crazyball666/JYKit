# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

JYKit is a multi-feature iOS utility library distributed via CocoaPods. It contains debugging tools, toast/HUD notifications, QR code scanning, and low-level runtime utilities.

## Architecture

The library is organized as a CocoaPods pod with **subspecs** for modular dependency:

| Subspec | Purpose |
|---------|---------|
| `DyTool` | Debug overlay with floating ball, performance monitoring (CPU/Memory/Network), file manager, log hook |
| `HUD` | Toast/notification UI |
| `QRCode` | Camera-based QR code scanner |
| `Tools` | Runtime utilities (device info, MsgSend forwarding, method hooking) |

**Dependency chain**: `DyTool` depends on `Tools` and `HUD`.

## Common Commands

```bash
# Install dependencies for example app
cd Example && pod install

# Lint the podspec (validate before publishing)
pod lib lint

# Run tests via xcodebuild
xcodebuild test -workspace Example/JYKit.xcworkspace -scheme JYKit-Example -sdk iphonesimulator

# Build only
xcodebuild build -workspace Example/JYKit.xcworkspace -scheme JYKit-Example
```

## Key Source Paths

- `JYKit/DyTool/Classes/` — Debug overlay (floating ball, performance views, file manager, log monitor)
- `JYKit/HUD/Classes/` — Toast UI
- `JYKit/QRCode/Classes/` — QR scanner (SwiftQRScanner, ImagePicker)
- `JYKit/Tools/Classes/` — Runtime tools (JYDeviceInfo, NSObject+MsgSend, Hooker)

## Development Notes

- iOS deployment target: 11.0, Swift 5.0
- The example app is configured with `use_frameworks!`
- Tests run against `JYKit_Example` scheme in the workspace
