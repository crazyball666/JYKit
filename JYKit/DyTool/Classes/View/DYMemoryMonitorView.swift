//
//  DYFloatingView.swift
//  JYKit
//
//  Created by crazyball on 2025/3/2.
//

import Foundation

class DYMonitorView: DYFloatingView {
    static let shared = DYMonitorView()
    
    private var refreshInterval: TimeInterval = 3
    private var timer: Timer?
    private var receivedFlow: UInt64 = 0
    private var sendFlow: UInt64 = 0
    
    override var safeFloatingAreaInsets: UIEdgeInsets {
        return .zero
    }
    
    lazy var textView: UILabel = {
        let textView = UILabel()
        if #available(iOS 13.0, *) {
            textView.font = UIFont.monospacedSystemFont(ofSize: 10, weight: .medium)
        } else {
            textView.font = UIFont(name: "Menlo-Regular", size: 10) ??
                                    UIFont(name: "Courier New", size: 10) ??
                                    UIFont.systemFont(ofSize: 10)
        }
        textView.numberOfLines = 0
        return textView
    }()
    
    init() {
        super.init(frame: .init(origin: .init(x: 0, y: 60), size: .init(width: 100, height: 60)))
        self.backgroundColor = .black.withAlphaComponent(0.3)
        self.addSubview(textView)
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        textView.leftAnchor.constraint(equalTo: self.leftAnchor).isActive = true
        textView.rightAnchor.constraint(equalTo: self.rightAnchor).isActive = true
        textView.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        let netFlow = NetInfo.requestNetFlow()
        receivedFlow = netFlow.totalReceived
        sendFlow = netFlow.totalSend
        edgePolicy = .allEdge
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func install() {
        super.install()
        startTimer()
    }
}

private extension DYMonitorView {
    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: self.refreshInterval, repeats: true) { [weak self] _ in
            guard let self = self else {
                return
            }
            let netFlow = NetInfo.requestNetFlow()
            defer {
                self.receivedFlow = netFlow.totalReceived
                self.sendFlow = netFlow.totalSend
            }
            let receiveSpeed = (Double(netFlow.totalReceived - self.receivedFlow) / self.refreshInterval).formattedAsDataSize()
            let sendSpeed = (Double(netFlow.totalSend - self.sendFlow) / self.refreshInterval).formattedAsDataSize()
            
            let mem  = "  Mem: \(JYDeviceInfo.footprintMemory().formattedAsDataSize())"
            let cpu  = "  CPU: \(String(format: "%.2f", JYDeviceInfo.appCpuUsage()))%"
            let send = " Send: \(sendSpeed)/s"
            let rec  = "  Rec: \(receiveSpeed)/s"

            textView.text = "\(mem)\n\(cpu)\n\(send)\n\(rec)"
        }
        timer?.fire()
    }
}

