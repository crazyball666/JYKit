//
//  DirectoryManageVC.swift
//  DynamicTools
//
//  Created by crazyball on 2023/7/31.
//

import UIKit

struct FileInfo {
    var path: String
    var name: String
    var isDirectory: Bool
    var creationDate: Date?
    var modificationDate: Date?
    var size: Int = 0
}



class DirectoryManageVC: UIViewController {
    var path: String
    
    init(path: String) {
        self.path = path
        super.init(nibName: nil, bundle: nil)
    }
    
    let tableView = UITableView()
    var contents = [FileInfo]() {
        didSet {
            tableView.reloadData()
        }
    }
    
    required init?(coder: NSCoder) { return nil }
        
    var directoryIcon: UIImage? = {
        return UIImage(inSDK: "directory.png")?.toSize(size: CGSize(width: 26, height: 26))
    }()
    
    var fileIcon: UIImage? = {
        return UIImage(inSDK: "file.png")?.toSize(size: CGSize(width: 26, height: 26))
    }()
    
    override func viewDidLoad() {
        navigationItem.title = (self.path as NSString).lastPathComponent
        loadContents()
        setupUI()
    }
    
    func loadContents() {
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: self.path)) ?? []
        self.contents = contents.compactMap({ (name) -> FileInfo? in
            guard let info = try? FileManager.default.attributesOfItem(atPath: self.path + "/" + name) else {
                return nil
            }
            return FileInfo(
                path: self.path + "/" + name,
                name: name,
                isDirectory: (info[.type] as? FileAttributeType) == FileAttributeType.typeDirectory,
                creationDate: info[.creationDate] as? Date,
                modificationDate: info[.modificationDate] as? Date,
                size: info[.size] as? Int ?? 0
            )
        })
    }
    
    func setupUI() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "FileItemCell")
        
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        tableView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        tableView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }
}

extension DirectoryManageVC: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return contents.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FileItemCell", for: indexPath)
        let model = contents[indexPath.row]
        cell.textLabel?.text = model.name
        cell.imageView?.image = model.isDirectory ? directoryIcon : fileIcon
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 40
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let model = contents[indexPath.row]
        if model.isDirectory {
            navigationController?.pushViewController(DirectoryManageVC(path: model.path), animated: true)
        } else {
            let sheet = UIAlertController(title: "操作", message: model.path, preferredStyle: .actionSheet)
            sheet.addAction(UIAlertAction(title: "查看", style: .default, handler: { _ in
                self.navigationController?.pushViewController(FileContentVC(path: model.path), animated: true)
            }))
            sheet.addAction(UIAlertAction(title: "导出", style: .default, handler: { _ in
                let filePath = URL(fileURLWithPath: model.path)
                let air = UIActivityViewController(activityItems: [filePath], applicationActivities: nil)
                if (UIDevice.current.userInterfaceIdiom == .pad) {
                    air.popoverPresentationController?.sourceView = self.view
                }
                self.present(air, animated: true, completion: nil)
            }))
            sheet.addAction(UIAlertAction(title: "复制路径", style: .default, handler: { _ in
                UIPasteboard.general.string = model.path
            }))
            sheet.addAction(UIAlertAction(title: "删除", style: .destructive, handler: { _ in
                Tools.showAlert(title: "确认删除？", confirmHandler: {
                    do {
                        try FileManager.default.removeItem(atPath: model.path)
                        JYToast.show("删除成功")
                        self.loadContents()
                    } catch {
                        JYToast.show("删除失败：" + error.localizedDescription)
                    }
                })
            }))
            sheet.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
            self.present(sheet, animated: true)
        }
    }
}


extension UIImage {
    func toSize(size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        self.draw(in: CGRect(origin: CGPoint.zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image ?? self
    }
}
