//
//  KeychainEditVC.swift
//  JYKit
//

import UIKit

final class KeychainEditVC: DYBaseVC {
    private var item: KeychainItem?
    private var selectedType: KeychainValueType = .string

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let keyLabel = UILabel()
    private let keyTextField = UITextField()
    private let typeLabel = UILabel()
    private let typeSegment = UISegmentedControl(items: KeychainValueType.allCases.map { $0.rawValue })
    private let valueLabel = UILabel()
    private let valueTextView = UITextView()
    private let hintLabel = UILabel()
    private let saveButton = UIButton(type: .system)
    private let copyButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)
    private let buttonStack = UIStackView()

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
        title = item == nil ? "添加条目" : "编辑条目"

        setupScrollView()
        setupUI()
        populateData()
        updateValueStyle()
    }

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }

    private func setupUI() {
        let margin: CGFloat = 16
        let cornerRadius: CGFloat = 8

        keyLabel.text = "Key"
        keyLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        keyTextField.borderStyle = .roundedRect
        keyTextField.placeholder = "输入 key"
        keyTextField.font = .systemFont(ofSize: 15)
        keyTextField.autocapitalizationType = .none
        keyTextField.clearButtonMode = .whileEditing

        typeLabel.text = "类型"
        typeLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        typeSegment.addTarget(self, action: #selector(typeChanged), for: .valueChanged)

        valueLabel.text = "Value"
        valueLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        valueTextView.layer.borderWidth = 1
        valueTextView.layer.borderColor = DYStyle.separator.cgColor
        valueTextView.layer.cornerRadius = cornerRadius
        valueTextView.backgroundColor = DYStyle.secondaryBackground
        valueTextView.textColor = DYStyle.text
        valueTextView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        valueTextView.font = .systemFont(ofSize: 14)

        hintLabel.font = .systemFont(ofSize: 12)
        hintLabel.textColor = DYStyle.secondaryText
        hintLabel.numberOfLines = 0
        hintLabel.text = "Bool 填写 true / false；Data 填写十六进制字符串"

        saveButton.setTitle("保存", for: .normal)
        saveButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        saveButton.backgroundColor = .systemBlue
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.layer.cornerRadius = cornerRadius
        saveButton.heightAnchor.constraint(equalToConstant: 46).isActive = true
        saveButton.addTarget(self, action: #selector(saveItem), for: .touchUpInside)

        copyButton.setTitle("复制 Value", for: .normal)
        copyButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        copyButton.backgroundColor = UIColor.systemGray.withAlphaComponent(0.15)
        copyButton.setTitleColor(.systemBlue, for: .normal)
        copyButton.layer.cornerRadius = cornerRadius
        copyButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        copyButton.addTarget(self, action: #selector(copyValue), for: .touchUpInside)

        deleteButton.setTitle("删除条目", for: .normal)
        deleteButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        deleteButton.backgroundColor = .systemRed
        deleteButton.setTitleColor(.white, for: .normal)
        deleteButton.layer.cornerRadius = cornerRadius
        deleteButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        deleteButton.addTarget(self, action: #selector(deleteItem), for: .touchUpInside)

        buttonStack.axis = .vertical
        buttonStack.spacing = 12
        buttonStack.addArrangedSubview(saveButton)
        buttonStack.addArrangedSubview(copyButton)
        if item != nil {
            buttonStack.addArrangedSubview(deleteButton)
        }

        [keyLabel, keyTextField, typeLabel, typeSegment, valueLabel, valueTextView, hintLabel, buttonStack].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            keyLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            keyLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin),

            keyTextField.topAnchor.constraint(equalTo: keyLabel.bottomAnchor, constant: 6),
            keyTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin),
            keyTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin),
            keyTextField.heightAnchor.constraint(equalToConstant: 40),

            typeLabel.topAnchor.constraint(equalTo: keyTextField.bottomAnchor, constant: 18),
            typeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin),

            typeSegment.topAnchor.constraint(equalTo: typeLabel.bottomAnchor, constant: 6),
            typeSegment.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin),
            typeSegment.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin),
            typeSegment.heightAnchor.constraint(equalToConstant: 32),

            valueLabel.topAnchor.constraint(equalTo: typeSegment.bottomAnchor, constant: 18),
            valueLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin),

            valueTextView.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 6),
            valueTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin),
            valueTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin),
            valueTextView.heightAnchor.constraint(equalToConstant: 180),

            hintLabel.topAnchor.constraint(equalTo: valueTextView.bottomAnchor, constant: 6),
            hintLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin),
            hintLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin),

            buttonStack.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 24),
            buttonStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin),
            buttonStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin),
            buttonStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30)
        ])
    }

    private func populateData() {
        guard let item = item else {
            typeSegment.selectedSegmentIndex = KeychainValueType.allCases.firstIndex(of: selectedType) ?? 0
            return
        }
        keyTextField.text = item.key
        keyTextField.isEnabled = false
        keyTextField.textColor = DYStyle.secondaryText
        typeSegment.selectedSegmentIndex = KeychainValueType.allCases.firstIndex(of: item.type) ?? 0
        // 禁止修改类型，避免与已存储的数据格式不匹配
        typeSegment.isEnabled = false
        valueTextView.text = stringValue(item)
    }

    private func updateValueStyle() {
        if selectedType == .data {
            valueTextView.font = DYStyle.monospacedFont(size: 13)
        } else {
            valueTextView.font = .systemFont(ofSize: 14)
        }

        switch selectedType {
        case .bool:
            hintLabel.text = "填写 true 或 false"
        case .int:
            hintLabel.text = "填写整数，例如 100"
        case .double:
            hintLabel.text = "填写浮点数，例如 3.14"
        case .data:
            hintLabel.text = "填写十六进制字符串，例如 01abff"
        case .string:
            hintLabel.text = "填写任意字符串"
        }
    }

    @objc private func typeChanged() {
        guard KeychainValueType.allCases.indices.contains(typeSegment.selectedSegmentIndex) else {
            return
        }
        selectedType = KeychainValueType.allCases[typeSegment.selectedSegmentIndex]
        updateValueStyle()
    }

    @objc private func saveItem() {
        guard let key = keyTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty else {
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
            let lower = valueString.lowercased()
            guard lower == "true" || lower == "1" || lower == "false" || lower == "0" else {
                JYToast.show("Bool 值请填写 true 或 false")
                return
            }
            value = (lower == "true" || lower == "1")
        case .int:
            guard let intValue = Int(valueString) else {
                JYToast.show("请输入有效的整数")
                return
            }
            value = intValue
        case .double:
            guard let doubleValue = Double(valueString) else {
                JYToast.show("请输入有效的浮点数")
                return
            }
            value = doubleValue
        case .data:
            guard let data = Data(hexString: valueString) else {
                JYToast.show("请输入有效的十六进制字符串")
                return
            }
            value = data
        }

        let didSave: Bool
        if let item = item {
            didSave = KeychainManager.save(key: key, value: value, type: type, service: item.service)
        } else {
            didSave = KeychainManager.save(key: key, value: value, type: type)
        }

        if didSave {
            onSave?()
            JYToast.show("保存成功")
            navigationController?.popViewController(animated: true)
        } else {
            JYToast.show("保存失败")
        }
    }

    @objc private func copyValue() {
        UIPasteboard.general.string = valueTextView.text
        JYToast.show("已复制")
    }

    @objc private func deleteItem() {
        guard let item = item else { return }
        Tools.showAlert(title: "确认删除？", message: item.key, confirmHandler: { [weak self] in
            if KeychainManager.delete(item: item) {
                JYToast.show("已删除")
                self?.onSave?()
                self?.navigationController?.popViewController(animated: true)
            } else {
                JYToast.show("删除失败")
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
