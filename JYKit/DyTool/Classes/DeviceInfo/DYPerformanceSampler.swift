//
//  DYPerformanceSampler.swift
//  JYKit
//
//  Created by Codex on 2026/6/6.
//

import UIKit

struct DYPerformanceSampleOptions: OptionSet {
    let rawValue: Int

    static let fps = DYPerformanceSampleOptions(rawValue: 1 << 0)
    static let appCPU = DYPerformanceSampleOptions(rawValue: 1 << 1)
    static let systemCPU = DYPerformanceSampleOptions(rawValue: 1 << 2)
    static let footprintMemory = DYPerformanceSampleOptions(rawValue: 1 << 3)
    static let availableMemory = DYPerformanceSampleOptions(rawValue: 1 << 4)
    static let network = DYPerformanceSampleOptions(rawValue: 1 << 5)
    static let battery = DYPerformanceSampleOptions(rawValue: 1 << 6)
    static let thermal = DYPerformanceSampleOptions(rawValue: 1 << 7)

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    init(metrics: [DYMonitorMetric]) {
        var options: DYPerformanceSampleOptions = []
        metrics.forEach { metric in
            switch metric {
            case .fps:
                options.insert(.fps)
            case .memory:
                options.insert(.footprintMemory)
            case .availableMemory:
                options.insert(.availableMemory)
            case .cpu:
                options.insert(.appCPU)
            case .systemCPU:
                options.insert(.systemCPU)
            case .sent, .received:
                options.insert(.network)
            case .battery:
                options.insert(.battery)
            case .thermal:
                options.insert(.thermal)
            }
        }
        self = options
    }
}

struct DYPerformanceSnapshot {
    let fps: Int?
    let cpuUsage: Float?
    let systemCpuUsage: Float?
    let footprintMemory: UInt64?
    let availableMemory: UInt64?
    let receivedBytesPerSecond: UInt64?
    let sentBytesPerSecond: UInt64?
    let batteryLevel: Float?
    let thermalState: ProcessInfo.ThermalState?
}

final class DYPerformanceSampler {
    private var lastFlowInfo: JYNetworkFlowInfo?
    private var lastSampleTime: TimeInterval?
    private var displayLink: CADisplayLink?
    private var displayLinkStartTime: CFTimeInterval = 0
    private var displayLinkFrameCount: Int = 0
    private var currentFPS: Int = 0
    private var activeOptions: DYPerformanceSampleOptions = []
    private var originalBatteryMonitoringState: Bool?

    func start(options: DYPerformanceSampleOptions) {
        activeOptions = options
        reset(options: options)
        if options.contains(.fps) {
            startDisplayLink()
        } else {
            stopDisplayLink()
        }
        updateBatteryMonitoring(isEnabled: options.contains(.battery))
    }

    func stop() {
        stopDisplayLink()
        restoreBatteryMonitoringIfNeeded()
        activeOptions = []
        lastFlowInfo = nil
        lastSampleTime = nil
    }

    func reset(options: DYPerformanceSampleOptions) {
        if options.contains(.network) {
            lastFlowInfo = JYDeviceInfo.networkFlow()
            lastSampleTime = ProcessInfo.processInfo.systemUptime
        } else {
            lastFlowInfo = nil
            lastSampleTime = nil
        }
        if options.contains(.systemCPU) {
            _ = JYDeviceInfo.cpuUsage()
        }
        displayLinkStartTime = 0
        displayLinkFrameCount = 0
        currentFPS = 0
    }

    func sample() -> DYPerformanceSnapshot {
        var receivedBytesPerSecond: UInt64?
        var sentBytesPerSecond: UInt64?

        if activeOptions.contains(.network) {
            let now = ProcessInfo.processInfo.systemUptime
            let flowInfo = JYDeviceInfo.networkFlow()
            let elapsed = lastSampleTime.map { max(now - $0, 0.001) } ?? 0
            let receivedDelta = byteDelta(current: flowInfo.totalReceivedBytes,
                                          previous: lastFlowInfo?.totalReceivedBytes)
            let sentDelta = byteDelta(current: flowInfo.totalSentBytes,
                                      previous: lastFlowInfo?.totalSentBytes)

            lastFlowInfo = flowInfo
            lastSampleTime = now
            receivedBytesPerSecond = bytesPerSecond(delta: receivedDelta, elapsed: elapsed)
            sentBytesPerSecond = bytesPerSecond(delta: sentDelta, elapsed: elapsed)
        }

        return DYPerformanceSnapshot(
            fps: activeOptions.contains(.fps) ? currentFPS : nil,
            cpuUsage: activeOptions.contains(.appCPU) ? JYDeviceInfo.appCpuUsage() : nil,
            systemCpuUsage: activeOptions.contains(.systemCPU) ? JYDeviceInfo.cpuUsage() : nil,
            footprintMemory: activeOptions.contains(.footprintMemory) ? JYDeviceInfo.footprintMemory() : nil,
            availableMemory: activeOptions.contains(.availableMemory) ? JYDeviceInfo.availableMemory() : nil,
            receivedBytesPerSecond: receivedBytesPerSecond,
            sentBytesPerSecond: sentBytesPerSecond,
            batteryLevel: activeOptions.contains(.battery) ? normalizedBatteryLevel() : nil,
            thermalState: activeOptions.contains(.thermal) ? ProcessInfo.processInfo.thermalState : nil
        )
    }

    private func startDisplayLink() {
        guard displayLink == nil else {
            return
        }
        let link = CADisplayLink(target: self, selector: #selector(onDisplayLinkTick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    private func updateBatteryMonitoring(isEnabled: Bool) {
        if isEnabled {
            if originalBatteryMonitoringState == nil {
                originalBatteryMonitoringState = UIDevice.current.isBatteryMonitoringEnabled
            }
            UIDevice.current.isBatteryMonitoringEnabled = true
        } else {
            restoreBatteryMonitoringIfNeeded()
        }
    }

    private func restoreBatteryMonitoringIfNeeded() {
        guard let originalState = originalBatteryMonitoringState else {
            return
        }
        UIDevice.current.isBatteryMonitoringEnabled = originalState
        originalBatteryMonitoringState = nil
    }

    @objc private func onDisplayLinkTick(_ link: CADisplayLink) {
        if displayLinkStartTime <= 0 {
            displayLinkStartTime = link.timestamp
            displayLinkFrameCount = 0
            return
        }

        displayLinkFrameCount += 1
        let elapsed = link.timestamp - displayLinkStartTime
        guard elapsed >= 1 else {
            return
        }
        currentFPS = Int(round(Double(displayLinkFrameCount) / elapsed))
        displayLinkStartTime = link.timestamp
        displayLinkFrameCount = 0
    }

    private func byteDelta(current: UInt64, previous: UInt64?) -> UInt64 {
        guard let previous = previous, current >= previous else {
            return 0
        }
        return current - previous
    }

    private func bytesPerSecond(delta: UInt64, elapsed: TimeInterval) -> UInt64 {
        guard elapsed > 0 else {
            return 0
        }
        return UInt64(Double(delta) / elapsed)
    }

    private func normalizedBatteryLevel() -> Float? {
        let level = UIDevice.current.batteryLevel
        guard level >= 0 else {
            return nil
        }
        return level
    }
}
