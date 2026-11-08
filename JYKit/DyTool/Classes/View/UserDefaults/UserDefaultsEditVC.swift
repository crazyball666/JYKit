//
//  UserDefaultsEditVC.swift
//  JYKit
//

import UIKit

class UserDefaultsEditVC: DYBaseVC {
    private var item: UserDefaultsItem?
    private var selectedType: UserDefaultsValueType = .string

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    // Key
    private let keyLabel = UILabel()
    private let keyTextField = UITextField()

    // Type
    private let typeLabel = UILabel()
    private let typeSegment = UISegmentedControl(items: UserDefaultsValueType.allCases.map { $0.rawValue })

    // Value - Bool
    private let boolContainer = UIView()
    private let boolSwitch = UISwitch()
    private let boolStatusLabel = UILabel()

    // Value - Number (Int / Double)
    private let numberTextField = UITextField()

    // Value - Multi-line (String / JSON / Data / Date)
    private let valueTextView = UITextView()
    private let formatJSONButton = UIButton(type: .system)

    // Action Buttons
    private let saveButton = UIButton(type: .system)
    private let copyButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)
    private let buttonStack = UIStackView()

    var onSave: (() -> Void)?

    init(item: UserDefaultsItem?) {
        self.item = item
        self.selectedType = item?.type ?? .string
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 13.0, *) {
            view.backgroundColor = .systemBackground
        } else {
            view.backgroundColor = .white
        }
        title = item == nil ? "添加条目" : "编辑条目"

        setupScrollView()
        setupUI()
        setupKeyboardNotifications()
        populateData()
        updateValueViewsForSelectedType()

        // 点击空白收起键盘
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: guide.topAnchor),
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

        // Key Label & TextField
        keyLabel.text = "Key"
        keyLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        keyLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(keyLabel)

        keyTextField.translatesAutoresizingMaskIntoConstraints = false
        keyTextField.borderStyle = .roundedRect
        keyTextField.placeholder = "请输入 Key（如 user_token）"
        keyTextField.font = .systemFont(ofSize: 15)
        keyTextField.clearButtonMode = .whileEditing
        keyTextField.autocapitalizationType = .none
        contentView.addSubview(keyTextField)

        // Type Label & Segment
        typeLabel.text = "类型 (Type)"
        typeLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        typeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(typeLabel)

        typeSegment.translatesAutoresizingMaskIntoConstraints = false
        typeSegment.addTarget(self, action: #selector(typeChanged(_:)), for: .valueChanged)
        contentView.addSubview(typeSegment)

        // Bool Container
        boolContainer.translatesAutoresizingMaskIntoConstraints = false
        boolContainer.layer.borderWidth = 1
        boolContainer.layer.borderColor = UIColor.lightGray.withAlphaComponent(0.3).cgColor
        boolContainer.layer.cornerRadius = cornerRadius
        if #available(iOS 13.0, *) {
            boolContainer.backgroundColor = .secondarySystemBackground
        } else {
            boolContainer.backgroundColor = UIColor(white: 0.97, alpha: 1.0)
        }
        contentView.addSubview(boolContainer)

        boolSwitch.translatesAutoresizingMaskIntoConstraints = false
        boolSwitch.addTarget(self, action: #selector(boolSwitchChanged(_:)), for: .valueChanged)
        boolContainer.addSubview(boolSwitch)

        boolStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        boolStatusLabel.font = .systemFont(ofSize: 16, weight: .medium)
        boolStatusLabel.text = "false"
        boolContainer.addSubview(boolStatusLabel)

        NSLayoutConstraint.activate([
            boolSwitch.leadingAnchor.constraint(equalTo: boolContainer.leadingAnchor, constant: 16),
            boolSwitch.centerYAnchor.constraint(equalTo: boolContainer.centerYAnchor),

            boolStatusLabel.leadingAnchor.constraint(equalTo: boolSwitch.trailingAnchor, constant: 16),
            boolStatusLabel.centerYAnchor.constraint(equalTo: boolContainer.centerYAnchor),
            boolContainer.heightAnchor.constraint(equalToConstant: 54)
        ])

        // Number TextField (Int / Double)
        numberTextField.translatesAutoresizingMaskIntoConstraints = false
        numberTextField.borderStyle = .roundedRect
        numberTextField.font = .systemFont(ofSize: 15)
        numberTextField.clearButtonMode = .whileEditing
        contentView.addSubview(numberTextField)

        // Multi-line TextView (String / JSON / Data / Date)
        valueTextView.translatesAutoresizingMaskIntoConstraints = false
        valueTextView.layer.borderWidth = 1
        valueTextView.layer.borderColor = UIColor.lightGray.withAlphaComponent(0.3).cgColor
        valueTextView.layer.cornerRadius = cornerRadius
        valueTextView.font = .systemFont(ofSize: 14)
        if #available(iOS 13.0, *) {
            valueTextView.backgroundColor = .secondarySystemBackground
        } else {
            valueTextView.backgroundColor = UIColor(white: 0.97, alpha: 1.0)
        }
        contentView.addSubview(valueTextView)

        // Format JSON Button
        formatJSONButton.translatesAutoresizingMaskIntoConstraints = false
        formatJSONButton.setTitle("格式化 / 验证 JSON", for: .normal)
        formatJSONButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        formatJSONButton.addTarget(self, action: #selector(formatJSON), for: .touchUpInside)
        contentView.addSubview(formatJSONButton)

        // Action Buttons
        saveButton.setTitle("保存", for: .normal)
        saveButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        saveButton.backgroundColor = .systemBlue
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.layer.cornerRadius = cornerRadius
        saveButton.heightAnchor.constraint(equalToConstant: 46).isActive = true
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)

        copyButton.setTitle("复制内容", for: .normal)
        copyButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        copyButton.backgroundColor = UIColor.systemGray.withAlphaComponent(0.15)
        copyButton.setTitleColor(.systemBlue, for: .normal)
        copyButton.layer.cornerRadius = cornerRadius
        copyButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        copyButton.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)

        deleteButton.setTitle("删除条目", for: .normal)
        deleteButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        deleteButton.backgroundColor = .systemRed
        deleteButton.setTitleColor(.white, for: .normal)
        deleteButton.layer.cornerRadius = cornerRadius
        deleteButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)

        buttonStack.axis = .vertical
        buttonStack.spacing = 12
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.addArrangedSubview(saveButton)
        buttonStack.addArrangedSubview(copyButton)
        if item != nil {
            buttonStack.addArrangedSubview(deleteButton)
        }
        contentView.addSubview(buttonStack)

        // Layout Constraints
        NSLayoutConstraint.activate([
            keyLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            keyLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin),

            keyTextField.topAnchor.constraint(equalTo: keyLabel.bottomAnchor, constant: 6),
            keyTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin),
            keyTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin),
            keyTextField.heightAnchor.constraint(equalToConstant: 40),

            typeLabel.topAnchor.constraint(equalTo: keyTextField.bottomAnchor, constant: 16),
            typeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin),

            typeSegment.topAnchor.constraint(equalTo: typeLabel.bottomAnchor, constant: 6),
            typeSegment.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin),
            typeSegment.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin),
            typeSegment.heightAnchor.constraint(equalToConstant: 32),

            boolContainer.topAnchor.constraint(equalTo: typeSegment.bottomAnchor, constant: 16),
            boolContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin),
            boolContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin),

            numberTextField.topAnchor.constraint(equalTo: typeSegment.bottomAnchor, constant: 16),
            numberTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin),
            numberTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin),
            numberTextField.heightAnchor.constraint(equalToConstant: 44),

            valueTextView.topAnchor.constraint(equalTo: typeSegment.bottomAnchor, constant: 16),
            valueTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin),
            valueTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin),
            valueTextView.heightAnchor.constraint(equalToConstant: 180),

            formatJSONButton.topAnchor.constraint(equalTo: valueTextView.bottomAnchor, constant: 6),
            formatJSONButton.trailingAnchor.constraint(equalTo: valueTextView.trailingAnchor),

            buttonStack.topAnchor.constraint(equalTo: valueTextView.bottomAnchor, constant: 40),
            buttonStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin),
            buttonStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin),
            buttonStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30)
        ])
    }

    private func populateData() {
        if let item = item {
            keyTextField.text = item.key
            keyTextField.isEnabled = false
            keyTextField.textColor = .gray

            selectedType = item.type
            if let idx = UserDefaultsValueType.allCases.firstIndex(of: item.type) {
                typeSegment.selectedSegmentIndex = idx
            }

            let preview = UserDefaultsManager.previewString(for: item.value, type: item.type)
            valueTextView.text = preview
            numberTextField.text = preview

            if item.type == .bool {
                let boolVal = (item.value as? Bool) ?? ((item.value as? NSNumber)?.boolValue ?? false)
                boolSwitch.isOn = boolVal
                boolStatusLabel.text = boolVal ? "true" : "false"
            }
        } else {
            typeSegment.selectedSegmentIndex = UserDefaultsValueType.allCases.firstIndex(of: .string) ?? 0
            selectedType = .string
            copyButton.isHidden = true
        }
    }

    private func updateValueViewsForSelectedType() {
        boolContainer.isHidden = (selectedType != .bool)
        numberTextField.isHidden = (selectedType != .int && selectedType != .double)
        valueTextView.isHidden = (selectedType == .bool || selectedType == .int || selectedType == .double)
        formatJSONButton.isHidden = (selectedType != .json)

        switch selectedType {
        case .bool:
            break
        case .int:
            numberTextField.placeholder = "请输入整数，如 100"
            numberTextField.keyboardType = .numbersAndPunctuation
        case .double:
            numberTextField.placeholder = "请输入浮点数，如 3.14159"
            numberTextField.keyboardType = .decimalPad
        case .json:
            valueTextView.font = UIFont(name: "Menlo", size: 13) ?? .monospacedSystemFont(ofSize: 13, weight: .regular)
        case .string, .data, .date:
            valueTextView.font = .systemFont(ofSize: 14)
        }
    }

    // MARK: - Actions
    @objc private func typeChanged(_ sender: UISegmentedControl) {
        guard let type = UserDefaultsValueType.allCases[safe: sender.selectedSegmentIndex] else { return }
        selectedType = type
        updateValueViewsForSelectedType()
    }

    @objc private func boolSwitchChanged(_ sender: UISwitch) {
        boolStatusLabel.text = sender.isOn ? "true" : "false"
    }

    @objc private func formatJSON() {
        let text = valueTextView.text ?? ""
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
              let formattedData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]),
              let formattedString = String(data: formattedData, encoding: .utf8) else {
            JYToast.show("JSON 语法解析错误")
            return
        }
        valueTextView.text = formattedString
        JYToast.show("格式化成功")
    }

    @objc private func saveTapped() {
        let key = keyTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !key.isEmpty else {
            JYToast.show("Key 不能为空")
            return
        }

        let rawValue: Any
        switch selectedType {
        case .bool:
            rawValue = boolSwitch.isOn
        case .int, .double:
            rawValue = numberTextField.text ?? ""
        case .string, .json, .data, .date:
            rawValue = valueTextView.text ?? ""
        }

        let result = UserDefaultsManager.save(key: key, value: rawValue, type: selectedType)
        if result.success {
            JYToast.show("保存成功")
            onSave?()
            navigationController?.popViewController(animated: true)
        } else {
            JYToast.show(result.message)
        }
    }

    @objc private func copyTapped() {
        let textToCopy: String
        switch selectedType {
        case .bool:
            textToCopy = boolSwitch.isOn ? "true" : "false"
        case .int, .double:
            textToCopy = numberTextField.text ?? ""
        case .string, .json, .data, .date:
            textToCopy = valueTextView.text ?? ""
        }
        UIPasteboard.general.string = textToCopy
        JYToast.show("已复制")
    }

    @objc private func deleteTapped() {
        guard let item = item else { return }
        Tools.showAlert(title: "确认删除条目？", message: item.key, confirmHandler: { [weak self] in
            UserDefaultsManager.delete(key: item.key)
            JYToast.show("已删除")
            self?.onSave?()
            self?.navigationController?.popViewController(animated: true)
        })
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Keyboard Handling
    private func setupKeyboardNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let keyboardHeight = keyboardFrame.height
        scrollView.contentInset.bottom = keyboardHeight
        if #available(iOS 13.0, *) {
            scrollView.verticalScrollIndicatorInsets.bottom = keyboardHeight
        } else {
            scrollView.scrollIndicatorInsets.bottom = keyboardHeight
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        scrollView.contentInset.bottom = 0
        if #available(iOS 13.0, *) {
            scrollView.verticalScrollIndicatorInsets.bottom = 0
        } else {
            scrollView.scrollIndicatorInsets.bottom = 0
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
