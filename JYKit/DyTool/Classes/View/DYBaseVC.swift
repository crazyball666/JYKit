//
//  BaseVC.swift
//  DynamicTools
//
//  Created by crazyball on 2023/3/28.
//

import Foundation


class DYBaseVC: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = "DyTool"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "关闭", style: .done, target: self, action: #selector(close))
    }
    
    @objc func close() {
        DYMainVC.shared.dismiss()
    }
}
