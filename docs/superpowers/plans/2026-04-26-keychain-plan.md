# Keychain 管理工具实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 DyTool 界面实现 Keychain 增删改查功能

**Architecture:** 通过 Security.framework 的 SecItemCopyMatching/SecItemAdd/SecItemUpdate/SecItemDelete API 操作 keychain，数据模型支持 String/Bool/Int/Double/Data 五种类型，UI 采用 dytool 现有风格

**Tech Stack:** Security.framework, UIKit

---

## 文件结构

```
JYKit/DyTool/Classes/
├── View/Keychain/
│   ├── KeychainListVC.swift     (新建)
│   └── KeychainEditVC.swift     (新建)
└── Tool/
    └── KeychainManager.swift    (新建，基于现有 SDKeyChain 改造)
```

---

## 任务清单

### Task 1: KeychainManager 核心 CRUD

**Files:**
- Create: `JYKit/DyTool/Classes/Tool/KeychainManager.swift`

- [ ] **Step 1: 创建 KeychainManager.swift**

```swift
import Foundation
import Security

enum KeychainValueType: String, CaseIterable {
    case string = "String"
    case bool = "Bool"
    case int = "Int"
    case double = "Double"
    case data = "Data"
}

struct KeychainItem {
    var key: String
    var value: Any
    var type: KeychainValueType
    var modified: Date = Date()
}

class KeychainManager {

    /// 列举所有 keychain 条目
    static func getAllItems() -> [KeychainItem] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "",
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let items = result as? [[String: Any]] else {
            return []
        }

        return items.compactMap { item -> KeychainItem? in
            guard let key = item[kSecAttrAccount as String] as? String,
                  let data = item[kSecValueData as String] as? Data else {
                return nil
            }

            // 尝试解析为 String
            if let str = String(data: data, encoding: .utf8) {
                return KeychainItem(key: key, value: str, type: .string)
            }

            // 尝试解析为 Bool
            if let bool = data.withUnsafeBytes({ $0.load(as: Bool.self) }) as Bool? {
                return KeychainItem(key: key, value: bool, type: .bool)
            }

            // 尝试解析为 Int
            if data.count == MemoryLayout<Int>.size {
                let num = data.withUnsafeBytes({ $0.load(as: Int.self) })
                return KeychainItem(key: key, value: num, type: .int)
            }

            // 尝试解析为 Double
            if data.count == MemoryLayout<Double>.size {
                let num = data.withUnsafeBytes({ $0.load(as: Double.self) })
                return KeychainItem(key: key, value: num, type: .double)
            }

            // 默认 Data
            return KeychainItem(key: key, value: data, type: .data)
        }
    }

    /// 保存条目（添加或更新）
    static func save(key: String, value: Any, type: KeychainValueType) -> Bool {
        // 先删除旧条目
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "",
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // 转换为 data
        var data: Data?
        switch type {
        case .string:
            if let str = value as? String {
                data = str.data(using: .utf8)
            }
        case .bool:
            var bool = value as? Bool ?? false
            data = Data(bytes: &bool, count: MemoryLayout<Bool>.size)
        case .int:
            var num = value as? Int ?? 0
            data = Data(bytes: &num, count: MemoryLayout<Int>.size)
        case .double:
            var num = value as? Double ?? 0
            data = Data(bytes: &num, count: MemoryLayout<Double>.size)
        case .data:
            data = value as? Data
        }

        guard let finalData = data else { return false }

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "",
            kSecAttrAccount as String: key,
            kSecValueData as String: finalData
        ]

        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    /// 删除条目
    static func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "",
            kSecAttrAccount as String: key
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}
```

- [ ] **Step 2: 提交**

```bash
git add JYKit/DyTool/Classes/Tool/KeychainManager.swift
git commit -m "feat: add KeychainManager with CRUD operations"
```

---

### Task 2: KeychainListVC 列表页

**Files:**
- Create: `JYKit/DyTool/Classes/View/Keychain/KeychainListVC.swift`

- [ ] **Step 1: 创建 KeychainListVC.swift**

```swift
//
//  KeychainListVC.swift
//  JYKit
//

import UIKit

class KeychainListVC: DYBaseVC {
    private var tableView = UITableView()
    private var items: [KeychainItem] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Keychain"
        view.backgroundColor = .white

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addItem)
        )

        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "KeychainCell")
        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
    }

    private func loadData() {
        items = KeychainManager.getAllItems()
        tableView.reloadData()
    }

    @objc private func addItem() {
        let editVC = KeychainEditVC(item: nil)
        editVC.onSave = { [weak self] in
            self?.loadData()
        }
        navigationController?.pushViewController(editVC, animated: true)
    }
}

extension KeychainListVC: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "KeychainCell", for: indexPath)
        let item = items[indexPath.row]

        cell.textLabel?.text = item.key
        cell.detailTextLabel?.text = "\(item.type.rawValue): \(previewValue(item))"

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = items[indexPath.row]
        let editVC = KeychainEditVC(item: item)
        editVC.onSave = { [weak self] in
            self?.loadData()
        }
        navigationController?.pushViewController(editVC, animated: true)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "删除") { [weak self] _, _, completion in
            guard let self = self else { return }
            let item = self.items[indexPath.row]
            if KeychainManager.delete(key: item.key) {
                self.items.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .automatic)
            }
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }

    private func previewValue(_ item: KeychainItem) -> String {
        switch item.type {
        case .string:
            return item.value as? String ?? ""
        case .bool:
            return (item.value as? Bool == true) ? "true" : "false"
        case .int:
            return "\(item.value as? Int ?? 0)"
        case .double:
            return "\(item.value as? Double ?? 0)"
        case .data:
            if let data = item.value as? Data {
                let hex = data.prefix(16).map { String(format: "%02x", $0) }.joined()
                return data.count > 16 ? "\(hex)..." : hex
            }
            return ""
        }
    }
}
```

- [ ] **Step 2: 提交**

```bash
git add JYKit/DyTool/Classes/View/Keychain/KeychainListVC.swift
git commit -m "feat: add KeychainListVC"
```

---

### Task 3: KeychainEditVC 编辑页

**Files:**
- Create: `JYKit/DyTool/Classes/View/Keychain/KeychainEditVC.swift`

- [ ] **Step 1: 创建 KeychainEditVC.swift**

```swift
//
//  KeychainEditVC.swift
//  JYKit
//

import UIKit

class KeychainEditVC: DYBaseVC {
    private var item: KeychainItem?
    private var selectedType: KeychainValueType = .string

    private let keyTextField = UITextField()
    private let typeSegment = UISegmentedControl(items: KeychainValueType.allCases.map { $0.rawValue })
    private let valueTextView = UITextView()
    private let saveButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)

    var onSave: (() -> Void)?

    init(item: KeychainItem?) {
        self.item = item
        self.selectedType = item?.type ?? .string
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = item == nil ? "添加条目" : "编辑条目"

        setupUI()

        if let item = item {
            keyTextField.text = item.key
            keyTextField.isEnabled = false
            typeSegment.selectedSegmentIndex = KeychainValueType.allCases.firstIndex(of: item.type) ?? 0
            valueTextView.text = stringValue(item)
        }
    }

    private func setupUI() {
        let labelWidth: CGFloat = 80

        // key
        let keyLabel = UILabel()
        keyLabel.text = "Key:"
        keyLabel.frame = CGRect(x: 16, y: 80, width: labelWidth, height: 30)
        view.addSubview(keyLabel)

        keyTextField.frame = CGRect(x: 16 + labelWidth, y: 80, width: view.bounds.width - 32 - labelWidth, height: 30)
        keyTextField.borderStyle = .roundedRect
        keyTextField.placeholder = "输入 key"
        view.addSubview(keyTextField)

        // type
        let typeLabel = UILabel()
        typeLabel.text = "Type:"
        typeLabel.frame = CGRect(x: 16, y: 130, width: labelWidth, height: 30)
        view.addSubview(typeLabel)

        typeSegment.frame = CGRect(x: 16 + labelWidth, y: 130, width: view.bounds.width - 32 - labelWidth, height: 30)
        typeSegment.selectedSegmentIndex = 0
        typeSegment.addTarget(self, action: #selector(typeChanged), for: .valueChanged)
        view.addSubview(typeSegment)

        // value
        let valueLabel = UILabel()
        valueLabel.text = "Value:"
        valueLabel.frame = CGRect(x: 16, y: 180, width: labelWidth, height: 30)
        view.addSubview(valueLabel)

        valueTextView.frame = CGRect(x: 16, y: 215, width: view.bounds.width - 32, height: 150)
        valueTextView.layer.borderColor = UIColor.lightGray.cgColor
        valueTextView.layer.borderWidth = 1
        valueTextView.font = .systemFont(ofSize: 14)
        view.addSubview(valueTextView)

        // buttons
        saveButton.setTitle("保存", for: .normal)
        saveButton.frame = CGRect(x: 16, y: 390, width: (view.bounds.width - 48) / 2, height: 44)
        saveButton.backgroundColor = .systemBlue
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.addTarget(self, action: #selector(saveItem), for: .touchUpInside)
        view.addSubview(saveButton)

        if item != nil {
            deleteButton.setTitle("删除", for: .normal)
            deleteButton.frame = CGRect(x: 16 + (view.bounds.width - 48) / 2 + 16, y: 390, width: (view.bounds.width - 48) / 2, height: 44)
            deleteButton.backgroundColor = .systemRed
            deleteButton.setTitleColor(.white, for: .normal)
            deleteButton.addTarget(self, action: #selector(deleteItem), for: .touchUpInside)
            view.addSubview(deleteButton)
        }
    }

    @objc private func typeChanged() {
        selectedType = KeychainValueType.allCases[typeSegment.selectedSegmentIndex]
    }

    @objc private func saveItem() {
        guard let key = keyTextField.text, !key.isEmpty else {
            JYToast.show("请输入 key")
            return
        }

        let valueString = valueTextView.text ?? ""
        let value: Any
        let type = selectedType

        switch type {
        case .string:
            value = valueString
        case .bool:
            value = valueString.lowercased() == "true" || valueString == "1"
        case .int:
            value = Int(valueString) ?? 0
        case .double:
            value = Double(valueString) ?? 0
        case .data:
            value = Data(hexString: valueString) ?? Data()
        }

        if KeychainManager.save(key: key, value: value, type: type) {
            onSave?()
            navigationController?.popViewController(animated: true)
        } else {
            JYToast.show("保存失败")
        }
    }

    @objc private func deleteItem() {
        guard let key = item?.key else { return }
        Tools.showAlert(title: "确认删除？", confirmHandler: { [weak self] in
            if KeychainManager.delete(key: key) {
                self?.onSave?()
                self?.navigationController?.popViewController(animated: true)
            }
        })
    }

    private func stringValue(_ item: KeychainItem) -> String {
        switch item.type {
        case .string:
            return item.value as? String ?? ""
        case .bool:
            return (item.value as? Bool == true) ? "true" : "false"
        case .int:
            return "\(item.value as? Int ?? 0)"
        case .double:
            return "\(item.value as? Double ?? 0)"
        case .data:
            if let data = item.value as? Data {
                return data.hexString
            }
            return ""
        }
    }
}
```

- [ ] **Step 2: 需要添加 Data.hexString 扩展，添加到 Ext.swift**

```swift
// 在 JYKit/DyTool/Classes/Tool/Ext.swift 添加
extension Data {
    var hexString: String {
        return map { String(format: "%02x", $0) }.joined()
    }

    init?(hexString: String) {
        let len = hexString.count / 2
        var data = Data(capacity: len)
        var index = hexString.startIndex
        for _ in 0..<len {
            let nextIndex = hexString.index(index, offsetBy: 2)
            guard let byte = UInt8(hexString[index..<nextIndex], radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }
        self = data
    }
}
```

- [ ] **Step 3: 提交**

```bash
git add JYKit/DyTool/Classes/View/Keychain/KeychainEditVC.swift JYKit/DyTool/Classes/Tool/Ext.swift
git commit -m "feat: add KeychainEditVC and Data.hexString extension"
```

---

### Task 4: 在 DYMainVC 添加入口

**Files:**
- Modify: `JYKit/DyTool/Classes/View/DYMainVC.swift`

- [ ] **Step 1: 在 items 数组添加"Keychain管理"**

在 `DYMainVC.swift` 的 MainToolVC items 数组中添加：

```swift
ToolItem(title: "Keychain管理", selector: #selector(showKeychain)),
```

- [ ] **Step 2: 添加 showKeychain 方法**

```swift
@objc func showKeychain() {
    navigationController?.pushViewController(KeychainListVC(), animated: true)
}
```

- [ ] **Step 3: 提交**

```bash
git add JYKit/DyTool/Classes/View/DYMainVC.swift
git commit -m "feat: add Keychain management entry in DyTool main menu"
```

---

## 自检清单

- [ ] KeychainManager 支持所有 5 种类型
- [ ] 列表页显示 key、type、value 预览
- [ ] 编辑页支持添加/编辑/删除
- [ ] Data 类型使用 hex 展示和输入
- [ ] DYMainVC 有入口可以进入 Keychain 管理页面
- [ ] 所有文件编译通过

---

## 执行选择

**Plan complete and saved to `docs/superpowers/plans/2026-04-26-keychain-plan.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?