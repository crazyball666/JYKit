# AGENTS.md

面向在本仓库中工作的 AI 编码代理（Claude Code、Codex、Cursor 等）。目标：改动可验证、风格一致、不踩已知坑。
人类开发者同样可以把它当作项目手册。

> 与 [CLAUDE.md](CLAUDE.md)、[README.md](README.md) 保持同步：命令、最低系统版本、发布流程发生变化时三处一起改。

---

## 1. 项目定位（不要违背的前提）

JYKit 是一个通过 CocoaPods 分发的 iOS 工具库，核心是 **DyTool —— 动态注入式调试 SDK**，常用于逆向分析、App 插件、内嵌诊断。

必须保留的设计（不要"优化"掉）：

- `Loader.m` 的 `+load` 自动调用 `DynamicTools.setup()`。这是注入场景的核心能力，**不要改成 `#if DEBUG` 或加开关**。
- 悬浮球 / 悬浮性能面板由独立 `UIWindow` 承载，悬浮于宿主 App 之上。
- 调试工具是"现场排查"用的，UI 文案为中文。

已被明确移除、**不要重新引入**：

- 崩溃捕获（`DYCrashRecorder`、崩溃日志页）
- 工具自检页（`DYDiagnosticsVC`）

---

## 2. 环境与版本约束

| 项目 | 值 |
|---|---|
| 源码 Pod (`JYKit.podspec`) | **iOS 13.0+**，Swift 5 |
| 二进制 Pod (`JYKitBinary.podspec`) | **iOS 15.0+**（当前 Xcode SDK 无法构建更低版本） |
| Example Demo (`Example/Podfile`) | **iOS 15.0**（强制，见下方说明） |
| Xcode | 新版（iOS 26 SDK）。本地 Xcode 的设备/模拟器部署版本下限均为 15.0 |

**关键约束：** 当前 Xcode SDK 已不支持 `< 15.0` 的部署版本（本地实测 device 与 simulator 都会报 `range of supported deployment target versions is 15.0 to 27.1.x`）。

因此：

- `Example/Podfile` 中 `platform :ios, '15.0'`，并通过 `post_install` 把 **所有 Pods target** 的 `IPHONEOS_DEPLOYMENT_TARGET` 抬到 15.0；Example App target 也是 15.0。
- `JYKitBinary.podspec` 声明 15.0，与 CI 产物一致。
- `JYKit.podspec` 仍声明 13.0（源码集成由宿主工程 Xcode 编译，老工程仍可用）。
- 修改部署版本时，同步：两个 podspec、`Example/Podfile`、Example 工程 target、README、本文件、CLAUDE.md。

---

## 3. 仓库结构

```
JYKit/
├── JYKit.podspec                 # 源码 Pod（subspec: DyTool / HUD / QRCode / Tools）
├── JYKitBinary.podspec           # 二进制 Pod 模板（版本号由 CI 按 tag 替换，勿手改 version）
├── .github/workflows/
│   └── release-binary.yml        # push v* tag → 构建 xcframework → 发布 GitHub Release
├── docs/superpowers/             # 历史上的设计稿 / 计划（plans, specs），可作为背景资料
├── Example/                      # Demo 工程；Example/Pods 已被 .gitignore
└── JYKit/
    ├── DyTool/Classes/
    │   ├── DynamicTools.swift    # 对外唯一入口 + 启动参数处理
    │   ├── Loader.m/.h           # +load 自动注入
    │   ├── DeviceInfo/           # DYPerformanceSampler（FPS/CPU/内存/网络采样）
    │   ├── LogMonitor/           # DYLog（增量日志文件）、PrintHook
    │   ├── SDFileManager/        # 文件封装
    │   ├── Tool/                 # Ext(UI/设备扩展)、Tool(通用工具)、
    │   │                         # KeychainManager、UserDefaultsManager、SDKeyChain
    │   └── View/
    │       ├── DYMainVC.swift            # 工具主面板（导航容器 + 分组菜单）
    │       ├── DYBaseVC.swift            # 工具页基类（统一背景、无关闭按钮）
    │       ├── DYMainWindow.swift        # 悬浮 UIWindow（场景挂载、触摸穿透）
    │       ├── DYFloatingView/Ball.swift # 悬浮球与拖拽靠边
    │       ├── DYMonitorView.swift       # 悬浮性能面板（点击打开面板）
    │       ├── DYMonitorSettingsVC.swift # 指标开关
    │       ├── DYLogVC.swift             # 日志查看（增量读取）
    │       ├── DYLagMonitorVC.swift      # 卡顿监控（RunLoop observer）
    │       ├── DYUIInspectorVC.swift     # UI 层级：浏览 / 点选 / 高亮 / 实时编辑
    │       ├── DYViewControllerStackVC.swift
    │       ├── DYAppInfoVC.swift
    │       ├── Common/                   # DYStyle、DYTextVC、DYSubtitleCell
    │       ├── FileManager/              # 沙盒 / 包体 / SQLite / 文本编辑
    │       ├── Keychain/                 # Keychain 列表 + 编辑
    │       ├── UserDefaults/             # UserDefaults 列表 + 编辑
    │       └── Log/                      # （空目录，可忽略）
    ├── HUD/Classes/Toast.swift           # JYToast
    ├── QRCode/Classes/                   # SwiftQRScanner、ImagePicker
    └── Tools/Classes/                    # JYDeviceInfo(.mm)、Hooker、NSObject+MsgSend
```

**Subspec 依赖**：`DyTool → Tools + HUD`。`QRCode`、`Tools`、`HUD` 可单独接入。

---

## 4. 架构与运行机制

### 4.1 启动流程

```
+[Loader load] → [DynamicTools setup]
                 ├─ PrintHook.hook()                    # hook printf/print 写入 DYLog
                 ├─ DYLagMonitor.startIfNeeded()        # 仅在 UserDefaults 开启时启动
                 ├─ 2s 后 showBall()                    # 悬浮球 + 悬浮监控
                 └─ 启动参数 -JYKitShowPanel 时直接打开面板
```

`DynamicTools` 是内部实现对外暴露的唯一 `public` 入口，其余类型保持 `internal`。

### 4.2 悬浮层

- `DYMainWindow`：`windowLevel = .statusBar + 1`，iOS 13+ 需 `attachToActiveSceneIfNeeded()` 绑定 `UIWindowScene`。
- 重写 `point(inside:)`，只有 `DYFloatingView` 子视图区域接收触摸，其余穿透给宿主 App。
- 面板打开时（`DYMainVC.viewWillAppear`）隐藏悬浮球与监控面板，关闭后恢复。
- 打开工具面板的统一方法：`DYMainVC.shared.present()`。

### 4.3 页面与视觉

- 所有工具页继承 `DYBaseVC`（统一背景色、不自动加"关闭"按钮；关闭只在首页有）。
- 视觉常量集中在 `DYStyle`：背景、分隔线、文字色、代码区、等宽字体、浅色 tint。
- 新页面用 `.insetGrouped` 表格；行高 `automaticDimension`。
- 搜索统一使用 **`UISearchBar`**（放在 header / tableHeaderView），**不要用 `UISearchController`**，原因见"已知坑"。
- 代码/日志类页面用 `DYStyle.codeBackground` + 白色文字；`DYTextVC` 可直接复用。

### 4.4 数据层

| 能力 | 实现 | 约束 |
|---|---|---|
| UserDefaults | `UserDefaultsManager` | 支持 7 种类型；系统 Key 与启动参数（NSArgumentDomain）从列表中过滤；`clearAll()` 跳过系统 Key |
| Keychain | `KeychainManager` | 5 种类型；按 service 分组展示 |
| 日志 | `DYLog` | 文件写入串行队列；`readNewLog(fromOffset:)` 增量读取，UI 不要整文件读 |
| 性能 | `DYPerformanceSampler` | 按所选指标采样，FPS 用 CADisplayLink |
| 卡顿 | `DYLagMonitor` | RunLoop observer；抓栈必须节流（见坑） |

---

## 5. 常用命令

```bash
# 安装依赖（改了 podspec / Podfile 后必须执行）
cd Example && pod install

# 构建 Demo（推荐，最快发现编译错误）
xcodebuild build \
  -workspace Example/JYKit.xcworkspace \
  -scheme JYKit-Example \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator'

# Podspec 校验（发布前必跑）
pod lib lint JYKit.podspec --allow-warnings --quick
```

> `JYKitBinary.podspec` 是发布模板，仓库内不做 lint；需要验证时请针对 Release 里发布的 podspec 进行。

**注意：`xcodebuild test` 当前不可用** —— Example 工程没有可用的测试 target（Pods 里残留 `Pods-JYKit_Tests` 引用，但工程无 native test target），命令会返回 `There are no test bundles available to test.`。
不要声称"测试通过"；请使用下面的验证流程。

---

## 6. 验证流程（每次改动都要做）

### 6.1 必做

1. `xcodebuild build ...`（见上）→ **BUILD SUCCEEDED**
2. 至少跑一次模拟器冒烟（涉及 UI 时）

### 6.2 模拟器冒烟

```bash
# 选择一个可用模拟器
xcrun simctl list devices available

xcrun simctl boot <UDID>
open -a Simulator            # 可选，需要看界面时

APP=$(ls -d ~/Library/Developer/Xcode/DerivedData/JYKit-*/Build/Products/Debug-iphonesimulator/JYKit_Example.app | head -1)
xcrun simctl install <UDID> "$APP"
xcrun simctl launch <UDID> com.crazyball.jykit -JYKitShowPanel -JYKitTool userdefaults

xcrun simctl io <UDID> screenshot /tmp/jykit.png
```

### 6.3 调试启动参数

| 参数 | 作用 |
|---|---|
| `-JYKitShowPanel` | 启动后直接打开工具面板（约 1s） |
| `-JYKitTool <name>` | 配合上一条直接进入指定页面 |

`<name>` 可选值：`monitor`、`lag`、`logs`、`inspector`、`vcstack`、`keychain`、`userdefaults`、`sandbox`、`bundle`、`appinfo`、`processinfo`、`memory`。
新增工具页时，在 `MainToolVC` 的 `ToolRow.keyword` 里补上对应标识，并更新本表与 README。

### 6.4 UI 改动检查项

- [ ] 浅色 / 深色模式都正常（不要硬编码 `.white` / `.black`，用 `DYStyle`）
- [ ] iPhone 窄屏 + iPad（分屏）不溢出；actionSheet 必须有 popover 锚点
- [ ] 至少在 **iOS 18** 与 **iOS 26** 两个模拟器上各看一次（系统搜索框、sheet 样式差异明显）
- [ ] 中文文案、与现有术语一致（例如「悬浮监控设置」「页面栈」）

---

## 7. 编码约定

- **Swift 5，UIKit 纯代码布局**，不使用 Storyboard/XIB。
- 新页面放在 `JYKit/DyTool/Classes/View/<Feature>/`，命名 `DY<Feature>VC`。
- 公共 UI/工具放 `View/Common/`；不要把多个页面塞进 `DYMainVC.swift`。
- 表格数据源优先复用 `DYSubtitleCell`，或自建 `UITableViewCell` 子类并显式布局。
- 对外 API 仅 `DynamicTools`；新增内部类型不要加 `public`。
- 日志/错误提示用 `JYToast.show(...)`；确认弹窗用 `Tools.showAlert(...)`。
- 工具页之间的导航只用 `navigationController?.pushViewController`。
- 新增用户可见功能后，更新 `README.md` 的功能列表与启动参数说明。
- 注释写"为什么"，不写"是什么"；已有中文注释风格保持一致。

### 7.1 新增一个工具页的标准步骤

1. 新建 `View/<Feature>/DY<Feature>VC.swift`，继承 `DYBaseVC`
2. 用 `DYStyle` 设置外观；表格用 `.insetGrouped`
3. 在 `MainToolVC.buildSections()` 增加 `ToolRow`（标题、副标题、SF Symbol、tint、handler、keyword）
4. 在 README 功能列表 + 启动参数表补一行
5. `xcodebuild build` + 模拟器用 `-JYKitTool <keyword>` 截图验证

---

## 8. 已知坑与硬约束（改之前先读）

### 8.1 UI

1. **不要在 `UISwitch` 的事件回调里同步刷新 tableView**
   共享 `accessoryView` + `reloadSections` 会因 UIKit 重入移除控件导致卡死。
   现有做法：`DYVisibilityCell` 每 Cell 独立 switch；回调里只改属性，刷新 `DispatchQueue.main.async` 延迟，并且只刷新非控件分区。
2. **不要隐藏包含调试面板的视图**
   `DYUIInspectorDetailVC.isToolHostingView(_:)` 会拦截 `UIWindow` 或面板祖先的隐藏 / 全透明操作，否则整个界面消失，看起来像卡死。新增"可能导致目标消失"的编辑能力时复用该判断。
3. **高亮不能用 alpha 淡出面板**
   sheet 的 presentation 容器仍会留下白色底板。现有实现：先 `dismiss` 面板 → 宿主界面闪烁高亮 → 重新 `present` 并回到详情页。
4. **iOS 26 上 `UISearchController` 会渲染成底部悬浮搜索条**，遮挡内容。所有页面统一用 `UISearchBar`。
5. actionSheet 在 iPad 上必须设置 `popoverPresentationController.sourceView/sourceRect` 或 `barButtonItem`，否则崩溃。
6. 弹窗"取消"按钮样式用 `.cancel`，不要用 `.destructive`。

### 8.2 性能

7. **卡顿监控抓栈必须节流**
   `DYLagMonitor.recordActivity` 只在 `beforeSources` / `afterWaiting` 且间隔 ≥ 0.5s 时调用 `Thread.callStackSymbols`。不要恢复成"每个 RunLoop activity 都抓栈"。
8. **日志页不要整文件读取**
   使用 `DYLog.readNewLog(fromOffset:)`，内存缓存上限 300K 字符，用户上滑查看历史时不要抢占滚动。
9. 悬浮监控的 `Timer` 要加入 `.common` mode，否则滚动时停止刷新。

### 8.3 发布

10. **不要随意删除再重建已发布的 tag**
    删除 tag 会让 GitHub 把已发布的 release 转为 **draft**（匿名 API 看不到）。workflow 已补 `--draft=false --latest` 兜底，但优先 bump 新版本。
11. `JYKitBinary.podspec` 的 `s.version` 由 CI 按 tag 替换，仓库里保持占位值即可；**deployment_target / summary 需要手动与实际保持一致**。
12. 发布后校验三件事：
    - `releases/latest` 的 tag 正确
    - 发布出来的 podspec 的 `sha256` 与 zip 实际哈希一致
    - 框架 `Info.plist` 的 `MinimumOSVersion` 与 podspec 声明一致

### 8.4 其他

13. `Date.time` 是本库扩展（`yyyy/MM/dd HH:mm:ss`），与任何新类型成员同名时注意歧义。
14. `UIDevice.dy_displayModel` 用于模拟器上避免显示 `arm64`；展示设备型号时用它。
15. 目录 `SharkSDK/`、`View/Log/` 为空，新增文件前确认是否应复用现有目录。
16. `Example/Pods` 为生成产物，禁止手改、禁止提交。

---

## 9. 发布流程

```bash
# 1. 更新版本
#    - JYKit.podspec: s.version
#    - README.md: 两处 JYKitBinary 下载地址 vX.Y.Z
#    - 如二进制最低版本变化，同步 JYKitBinary.podspec

# 2. 本地校验
pod lib lint JYKit.podspec --allow-warnings --quick
cd Example && pod install
xcodebuild build -workspace JYKit.xcworkspace -scheme JYKit-Example \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator'

# 3. 提交并打 tag（建议先建分支，再 ff 合并到 main，保持线性历史）
git tag vX.Y.Z
git push origin main
git push origin vX.Y.Z
```

CI（`.github/workflows/release-binary.yml`）自动：
1. 解析 tag 版本
2. 分别构建 iOS / Simulator 的 archive
3. 合成 `JYKit.xcframework` 并校验 `SDKImages.bundle`
4. 打包 zip、计算 sha256、生成 `JYKitBinary.podspec`
5. 创建或更新 GitHub Release

### 发布后校验（本机可能没有 `gh`，用 curl + Python）

```bash
curl -s "https://api.github.com/repos/crazyball666/JYKit/releases/latest" \
  | python3 -c "import sys,json; d=json.loads(sys.stdin.read(), strict=False); print(d['tag_name'], [a['name'] for a in d['assets']])"

curl -sL "https://github.com/crazyball666/JYKit/releases/download/vX.Y.Z/JYKitBinary.podspec" \
  | grep -E "s.version|deployment_target|sha256"

# 下载 zip 校验最小系统版本
unzip -q JYKit.xcframework.zip -d /tmp/jykit && \
  plutil -p /tmp/jykit/JYKit.xcframework/ios-arm64/JYKit.framework/Info.plist | grep MinimumOSVersion
```

若 CI 失败且无法查看日志（无 `gh` 权限），可通过 `/actions/runs/<id>/jobs` 查看失败 step；常见原因是部署版本与 Xcode SDK 不兼容。

---

## 10. AI 工作清单

**开工前**
- [ ] 读本文件、`CLAUDE.md`、`README.md`
- [ ] `git status` 确认没有未预期的本地改动
- [ ] 先跑一次 `xcodebuild build` 建立基线

**改动中**
- [ ] 遵循第 7 节约定，新代码不复制粘贴历史坏模式
- [ ] 涉及第 8 节的区域时逐条对照
- [ ] 不修改 `Example/Pods`、`DerivedData`、`.DS_Store`
- [ ] 不引入崩溃捕获 / 自检页 / 关闭 `+load` 自动启动

**收尾**
- [ ] `xcodebuild build` 通过
- [ ] UI 改动在 iOS 18 + iOS 26 模拟器各验证一次，必要时截图
- [ ] 更新 README（功能、启动参数）；版本变更同步三份文档
- [ ] 提交信息用约定式前缀（`feat(dytool):` / `fix(ui):` / `ci:` / `docs:`），正文可用中文
- [ ] 未获明确要求，不执行 `git push`、不发布 tag / Release

---

## 11. 边界

- 这是调试/逆向辅助工具，**只用于授权范围内的 App**。
- 不引入私有 API、不绕过系统安全机制、不做越狱环境适配。
- Keychain/UserDefaults 展示能力仅用于本机调试包；不要把它当作数据脱敏或安全存储方案。
- SDK 会 hook `print` 并常驻悬浮窗，正式商店包接入前需评估（README 已提示）。
