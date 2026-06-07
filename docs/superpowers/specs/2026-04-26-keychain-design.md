# Keychain 管理工具设计

## 概述

在 DyTool 界面增加一个 Keychain 管理功能，支持增删改查当前 App 的 keychain 条目。

## 数据模型

```
KeychainItem
├── key: String
├── value: Any (String/Bool/Int/Double/Data)
├── type: KeychainValueType
└── modified: Date
```

KeychainValueType 枚举：
- `string`
- `bool`
- `int`
- `double`
- `data`

## 界面结构

```
DYMainVC
└── items[] (工具列表)
    └── "Keychain管理" → KeychainListVC

KeychainListVC (UITableView)
├── 导航栏：标题 "Keychain"，右侧 + 按钮
├── 列表 cell：key / 类型标签 / value 预览
├── 左滑删除
└── 点击 cell → KeychainEditVC (编辑模式)

KeychainEditVC (表单)
├── key 输入框
├── type 选择器 (segmentedControl: String/Bool/Int/Double/Data)
├── value 输入框 (根据 type 切换)
└── 底部：保存 / 删除按钮
```

## 实现方案

### 枚举 keychain 条目

通过 `SecItemCopyMatching` 查询所有属于当前 app 的 keychain 条目：

```swift
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: Bundle.main.bundleIdentifier ?? "",
    kSecReturnAttributes as String: true,
    kSecMatchLimit as String: kSecMatchLimitAll
]
```

### CRUD 操作

| 操作 | API |
|------|-----|
| 列举 | `SecItemCopyMatching` |
| 添加 | `SecItemAdd` |
| 更新 | `SecItemUpdate` |
| 删除 | `SecItemDelete` |

### Data 类型展示

- 列表页：hex 预览（前 32 字节）
- 编辑页：支持 hex 输入 / base64 切换

## UI 风格

- 复用 `DYBaseVC`
- 与 `DirectoryManageVC` 文件管理风格一致
- 颜色、字体遵循 JYKit 规范

## 依赖

- 仅使用系统 Security.framework
- 不引入额外三方库

## 文件结构

```
JYKit/DyTool/Classes/
├── View/Keychain/
│   ├── KeychainListVC.swift
│   └── KeychainEditVC.swift
└── Tool/
    └── KeychainManager.swift  (原 SDKeyChain 改名/扩展)
```

## 操作流程

1. **列表页** — 启动时加载并显示所有条目
2. **添加** — 点击 +，打开空白表单，选择类型，输入 key/value，保存
3. **编辑** — 点击 cell，打开预填充表单，修改后保存
4. **删除** — 左滑 cell，点击删除，确认后删除