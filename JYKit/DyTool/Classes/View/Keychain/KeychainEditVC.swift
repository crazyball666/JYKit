//
//  KeychainEditVC.swift
//  JYKit
//

import UIKit

class KeychainEditVC: DYBaseVC {
    private var item: KeychainItem?
    private var selectedType: KeychainValueType = .string

    private let scrollView = UIScrollView()
    private let contentView = UIView()
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

        setupScrollView()
        setupUI()

        if let item = item {
            keyTextField.text = item.key
            keyTextField.isEnabled = false
            typeSegment.selectedSegmentIndex = KeychainValueType.allCases.firstIndex(of: item.type) ?? 0
            typeSegment.isEnabled = false  // 禁止修改类型，避免类型不匹配
            valueTextView.text = stringValue(item)
        } else {
            typeSegment.selectedSegmentIndex = KeychainValueType.allCases.firstIndex(of: selectedType) ?? 0
        }
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
        let labelWidth: CGFloat = 80
        let leadingInset: CGFloat = 16
        let trailingInset: CGFloat = 16
        let stackSpacing: CGFloat = 16
        let cornerRadius: CGFloat = 8

        // key label
        let keyLabel = UILabel()
        keyLabel.text = "Key:"
        keyLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(keyLabel)

        // key text field
        keyTextField.translatesAutoresizingMaskIntoConstraints = false
        keyTextField.borderStyle = .roundedRect
        keyTextField.placeholder = "输入 key"
        keyTextField.layer.cornerRadius = cornerRadius
        keyTextField.clipsToBounds = true
        contentView.addSubview(keyTextField)

        // type label
        let typeLabel = UILabel()
        typeLabel.text = "Type:"
        typeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(typeLabel)

        // type segment
        typeSegment.translatesAutoresizingMaskIntoConstraints = false
        typeSegment.addTarget(self, action: #selector(typeChanged), for: .valueChanged)
        contentView.addSubview(typeSegment)

        // value label
        let valueLabel = UILabel()
        valueLabel.text = "Value:"
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(valueLabel)

        // value text view
        valueTextView.translatesAutoresizingMaskIntoConstraints = false
        valueTextView.layer.borderColor = UIColor.lightGray.cgColor
        valueTextView.layer.borderWidth = 1
        valueTextView.layer.cornerRadius = cornerRadius
        valueTextView.font = .systemFont(ofSize: 14)
        contentView.addSubview(valueTextView)

        // save button
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.setTitle("保存", for: .normal)
        saveButton.backgroundColor = .systemBlue
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.layer.cornerRadius = cornerRadius
        saveButton.addTarget(self, action: #selector(saveItem), for: .touchUpInside)
        contentView.addSubview(saveButton)

        // delete button (if editing existing item)
        var deleteButtonConstraints: [NSLayoutConstraint] = []
        if item != nil {
            deleteButton.translatesAutoresizingMaskIntoConstraints = false
            deleteButton.setTitle("删除", for: .normal)
            deleteButton.backgroundColor = .systemRed
            deleteButton.setTitleColor(.white, for: .normal)
            deleteButton.layer.cornerRadius = cornerRadius
            deleteButton.addTarget(self, action: #selector(deleteItem), for: .touchUpInside)
            contentView.addSubview(deleteButton)

            let buttonWidth = (UIScreen.main.bounds.width - 48 - leadingInset - trailingInset) / 2
            deleteButtonConstraints = [
                deleteButton.topAnchor.constraint(equalTo: valueTextView.bottomAnchor, constant: stackSpacing),
                deleteButton.leadingAnchor.constraint(equalTo: saveButton.trailingAnchor, constant: 16),
                deleteButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -trailingInset),
                deleteButton.heightAnchor.constraint(equalToConstant: 44),
                deleteButton.widthAnchor.constraint(equalToConstant: buttonWidth)
            ]
        }

        // save button width constraint
        let saveButtonWidth = saveButton.widthAnchor.constraint(equalToConstant: (UIScreen.main.bounds.width - 48 - leadingInset - trailingInset) / 2)
        saveButtonWidth.priority = .defaultHigh
        saveButtonWidth.isActive = true

        NSLayoutConstraint.activate([
            // key label
            keyLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            keyLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: leadingInset),
            keyLabel.widthAnchor.constraint(equalToConstant: labelWidth),

            // key text field
            keyTextField.centerYAnchor.constraint(equalTo: keyLabel.centerYAnchor),
            keyTextField.leadingAnchor.constraint(equalTo: keyLabel.trailingAnchor, constant: 8),
            keyTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -trailingInset),
            keyTextField.heightAnchor.constraint(equalToConstant: 30),

            // type label
            typeLabel.topAnchor.constraint(equalTo: keyLabel.bottomAnchor, constant: stackSpacing),
            typeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: leadingInset),
            typeLabel.widthAnchor.constraint(equalToConstant: labelWidth),

            // type segment
            typeSegment.centerYAnchor.constraint(equalTo: typeLabel.centerYAnchor),
            typeSegment.leadingAnchor.constraint(equalTo: typeLabel.trailingAnchor, constant: 8),
            typeSegment.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -trailingInset),
            typeSegment.heightAnchor.constraint(equalToConstant: 30),

            // value label
            valueLabel.topAnchor.constraint(equalTo: typeLabel.bottomAnchor, constant: stackSpacing),
            valueLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: leadingInset),
            valueLabel.widthAnchor.constraint(equalToConstant: labelWidth),

            // value text view - with minimum height and ability to expand
            valueTextView.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 8),
            valueTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: leadingInset),
            valueTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -trailingInset),
            valueTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 150),

            // save button
            saveButton.topAnchor.constraint(equalTo: valueTextView.bottomAnchor, constant: stackSpacing),
            saveButton.heightAnchor.constraint(equalToConstant: 44),

            // bottom constraint for content view
            contentView.bottomAnchor.constraint(equalTo: saveButton.bottomAnchor, constant: 24)
        ] + deleteButtonConstraints)

        // Center save button when no delete button
        if item == nil {
            saveButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor).isActive = true
        } else {
            saveButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: leadingInset).isActive = true
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