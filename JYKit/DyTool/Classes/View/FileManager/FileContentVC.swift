//
//  FileContentVC.swift
//  DynamicTools
//
//  Created by crazyball on 2023/7/31.
//

import Foundation

class FileContentVC: UIViewController {
    let path: String
    
    init(path: String) {
        self.path = path
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { return nil }
    
    override func viewDidLoad() {
        view.backgroundColor = .white
        navigationItem.title = (self.path as NSString).lastPathComponent
        let pathExtension = (self.path as NSString).pathExtension
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "导出", style: .done, target: self, action: #selector(onTapExport))
        
        if ["png", "jpg", "jpeg"].contains(pathExtension) {
            let imageView = UIImageView()
            view.addSubview(imageView)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
            imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
            imageView.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.8).isActive = true
            imageView.heightAnchor.constraint(lessThanOrEqualTo: view.heightAnchor, multiplier: 0.8).isActive = true
            imageView.image = UIImage(contentsOfFile: path)
        } else {
            let contentView = UITextView()
            view.addSubview(contentView)
            contentView.backgroundColor = .black
            contentView.textColor = .white
            contentView.isEditable = false
            contentView.translatesAutoresizingMaskIntoConstraints = false
            contentView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
            contentView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
            contentView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
            
            let content: String
            do {
                switch pathExtension {
                case "plist":
                    content = try getPlistData()
                default:
                    content = try String(contentsOfFile: path)
                }
            } catch {
                content = "读取失败：\(error.localizedDescription)"
            }
            contentView.text = content
        }
    }
    
    
    @objc func onTapExport() {
        let filePath = URL(fileURLWithPath: path)
        let air = UIActivityViewController(activityItems: [filePath], applicationActivities: nil)
        if (UIDevice.current.userInterfaceIdiom == .pad) {
            air.popoverPresentationController?.sourceView = self.view
        }
        self.present(air, animated: true, completion: nil)
        
//        let filePath = URL(fileURLWithPath: path)
//        let vc = UIDocumentInteractionController(url: filePath)
//        vc.presentOpenInMenu(from: CGRect.zero, in: self.view, animated: true)
    }
}

extension FileContentVC {
    func getPlistData() throws -> String {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let info = try PropertyListSerialization.propertyList(from: data, format: nil)
        print(info)
        let xml = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        return String(data: xml, encoding: .utf8) ?? ""
    }
}

