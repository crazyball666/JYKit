//
//  DYMainVC.swift
//  DyTool
//
//  Created by crazyball on 2022/7/17.
//

import UIKit

fileprivate struct ToolItem {
    var title: String
    var selector: Selector
    var userInfo: Any?
}

class DYMainVC: UINavigationController {
    static let shared = DYMainVC(rootViewController: MainToolVC())
    
    override func viewDidLoad() {
        view.backgroundColor = .white
        navigationBar.backgroundColor = .white
    }
    
    func present() {
        guard let topVC = Tools.rootVC()?.topVC(), topVC != self else {
            return
        }
        if self.isBeingPresented {
            self.dismiss(animated: false) {
                topVC.present(self, animated: true, completion: nil)
            }
            return
        }
        topVC.present(self, animated: true, completion: nil)
    }
    
    func dismiss() {
        self.dismiss(animated: true)
    }
}


fileprivate class MainToolVC: DYBaseVC {
    private var tableView = UITableView()
    private var items = [
        ToolItem(title: "日志查看", selector: #selector(showLogs)),
//        ToolItem(title: "性能监控", selector: #selector(showPerform)),
        ToolItem(title: "清空KeyChain", selector: #selector(clearKeyChain)),
        ToolItem(title: "清空UserDefault", selector: #selector(clearUserDefault)),
        ToolItem(title: "获取ProcessInfo参数", selector: #selector(getProcessInfo)),
        ToolItem(title: "沙盒文件管理", selector: #selector(goFileManage)),
        ToolItem(title: "包体文件管理", selector: #selector(goAppFileManage)),
//        ToolItem(title: "测试Crash", selector: #selector(testCrash)),
//        ToolItem(title: "Crash日志", selector: #selector(exportCrash)),
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(tableView)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "MainToolCell")
        tableView.dataSource = self
        tableView.delegate = self
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        tableView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        tableView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }
}


extension MainToolVC {
    @objc func showLogs() {
        navigationController?.pushViewController(DYLogVC(), animated: true)
    }
    
    @objc func showPerform() {
        navigationController?.pushViewController(SDPerformVC(), animated: true)
    }
    
    @objc func clearKeyChain() {
        Tools.showAlert(title: "确认清空 KeyChain？", confirmHandler: {
            Tools.clearAllKeyChainItems()
            JYToast.show("已清空KeyChain")
        })
    }
    
    @objc func clearUserDefault() {
        Tools.showAlert(title: "确认清空 UserDefault？", confirmHandler: {
            Tools.clearAllUserDefault()
            JYToast.show("已清空UserDefault")
        })
    }
    
    @objc func getProcessInfo() {
        let args = ProcessInfo.processInfo.arguments
        Tools.showAlert("\(args)")
    }
    
    @objc func goFileManage() {
        navigationController?.pushViewController(DirectoryManageVC(path: NSHomeDirectory()), animated: true)
    }
    
    @objc func goAppFileManage() {
        navigationController?.pushViewController(DirectoryManageVC(path: Bundle.main.bundlePath), animated: true)
    }
}




extension MainToolVC: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
        
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MainToolCell", for: indexPath)
        let row = indexPath.row
        let model = items[row]
        cell.textLabel?.text = model.title
        cell.imageView?.image = UIImage(inSDK: "icon.png")
        
        let size = CGSize(width: 40, height: 40)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        cell.imageView?.image?.draw(in: CGRect(origin: CGPoint.zero, size: size))
        cell.imageView?.image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let row = indexPath.row
        
        let model = items[row]
        if responds(to: model.selector) {
            if model.userInfo == nil {
                perform(model.selector)
            } else {
                perform(model.selector, with: model.userInfo)
            }
        }
    }
}
