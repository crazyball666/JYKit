//
//  PerformMonitor.swift
//  SwiftDebug
//
//  Created by linzixin on 2021/12/19.
//

import Foundation
class PerformMonitor {
    typealias UpdateBlock = (_ cpu: Float, _ memory: Float, _ downloadRate: UInt64, _ uploadRate: UInt64) -> Void
    static let shared: PerformMonitor = PerformMonitor()
    private var cpuInfo: CPUInfo = CPUInfo()
    private var memoryInfo: MemoryInfo = MemoryInfo()
    private var timer: Timer!
    /// 获取CPU核心数
    var cpuCore: Int { return cpuInfo.physicalCoreCount }
    /// 获取总运行内存（GB）
    var allMemory: Float { return Float(memoryInfo.physicalMemory) }
    /// 刷新间隔
    var refreshInterval: Double = 1
    
    /// cpu 使用率
    /// memory 使用的内存(MB)
    private var updateBlock: UpdateBlock = {cpu,memory,download,upload in }
    private var receivedFlow: UInt64 = 0
    private var sendFlow: UInt64 = 0
    private var flowRate: (downloadRate: UInt64, uploadRate: UInt64) {
        let netFlow = NetInfo.requestNetFlow()
        defer {
            receivedFlow = netFlow.totalReceived
            sendFlow = netFlow.totalSend
        }
        return (netFlow.totalReceived - receivedFlow, netFlow.totalSend - sendFlow)
    }
    /// 初始化
    init() {
        let netFlow = NetInfo.requestNetFlow()
        receivedFlow = netFlow.totalReceived
        sendFlow = netFlow.totalSend
    }
    /// 开始性能检测
    func startMonitor(interval: Double = 1, block: @escaping UpdateBlock) {
        if refreshInterval != interval {
            stopMonitor()
        }
        refreshInterval = interval
        updateBlock = block
        if timer != nil, timer.isValid {
            return
        }
        timer = Timer(timeInterval: refreshInterval, target: self, selector: #selector(refreshAction), userInfo: nil, repeats: true)
        timer.fire()
        RunLoop.current.add(timer, forMode: .common)
    }
    
    /// 停止性能检测
    func stopMonitor() {
        if timer != nil {
            timer.invalidate()
            timer = nil
        }
    }
    
    @objc private func refreshAction() {
        let cpu: Float = Float(cpuInfo.used)
        let memory: Float = Float(memoryInfo.getMemory())
        let rate = flowRate
        updateBlock(cpu, Float(JYDeviceInfo.footprintMemory() >> 20), rate.downloadRate, rate.uploadRate)
    }
    
}
