//
//  HRCDownloder.swift
//  HuracanDownloader
//
//  Created by pulei yu on 2023/10/26.
//

import Foundation

open class HRCDownloder: NSObject {
    public var dataProvider: HRCDownloadDataProvider!

    open func pauseAll() {
        let tasks = dataProvider.underwayTasks
        tasks.forEach { self.pause(task: $0) }
        cancelTimer()
    }

    /// 暂停某一个任务
    open func pause(task: HRCTask) {
        guard let receipt = receipt(of: task) else { return }
        HRCDownloadMaid.oneInstance().suspend(withDownloadReceipt: receipt)
    }

    open func startAllTasks() {
        __beginDownload()
    }

    /// 开始某一个任务
    open func start(task: HRCTask) {
        dataProvider.update(task: task, state: .notStart)
        __download(task: task)
    }

    open func syncTaskInfo(_ task: HRCTask) {
        guard let receipt = receipt(of: task) else { return }

        dataProvider.update(task: task, speed: receipt.speed, downloadedSize: Int(receipt.totalWritten), dummyStep: nil)
    }

    open func delete(tasks: [HRCTask]) {
        tasks.forEach {
            self.pause(task: $0)
            if let receipt = self.receipt(of: $0) {
                receipt.failureBlock = { _, _, _ in }
                receipt.successBlock = { _, _, _ in }
                receipt.progressBlock = { _, _ in }
                HRCDownloadMaid.oneInstance().remove(with: receipt)
            }
        }
    }

    public var dmTimer: DispatchSourceTimer?
}

// MARK: - Download Step

extension HRCDownloder {
    @objc open func __beginDownload() {
        guard let task = dataProvider.underwayTasks.first(where: { $0.state != .ing && $0.state != .paused }) else { return }
        __download(task: task)
    }

    @objc open func __download(task: HRCTask) {
        guard task.isDummy == false else {
            beginDMDownload()
            return
        }

        if task.__needsQueryUrl {
            dataProvider.fetchRealUrl(of: task) { [weak self] newTask in
                if let newTask = newTask {
                    self?.__realDownload(task: newTask)
                } else {
                    self?.dataProvider.update(task: task, state: .failed)
                    self?.__beginDownload()
                }
            }
        } else {
            if let receipt = receipt(of: task),
               receipt.lastState == .urlFailed {
                // 需要更新其下载地址信息
                dataProvider.fetchRealUrl(of: task) { [weak self] newTask in
                    if let newTask = newTask {
                        HRCDownloadMaid.oneInstance().update(receipt, url: newTask.url, headers: newTask.headerJSONStr)
                        self?.__realDownload(task: newTask)
                    } else {
                        self?.__beginDownload()
                    }
                }
            } else {
                __realDownload(task: task)
            }
        }
    }

    @objc open func __realDownload(task: HRCTask) {
        assert(task.__needsQueryUrl == false)

        dataProvider.update(task: task, state: .ing)

        if let receipt = receipt(of: task) {
            if receipt.state == .completed {
                __success(task: task)
                return
            }
            if receipt.state == .failed && receipt.lastState != .urlFailed {
                __failed(task: task)
                return
            }
        }
        // 解密操作
        if task.isEncrypted,
           let taskURL = dataProvider.taskNeedsTransmit(task: task) {
            dataProvider.update(task: task, url: taskURL.absoluteString)
        }

        HRCDownloadMaid.oneInstance().downFile(withURL: task.url,
                                               headers: task.headerJSONStr,
                                               progress: nil,
                                               target: nil) { _, _, _ in
            self.__success(task: task)
        } failure: { req, _, _ in
            if let urlStr = req.url?.absoluteString,
               let receipt = HRCDownloadMaid.oneInstance().downReceipt(forURL: urlStr),
               receipt.lastState == .urlFailed || receipt.lastState == .suspened {
                self.dataProvider.update(task: task, state: .paused)
            } else {
                self.__failed(task: task)
            }
        }
    }

    @objc open func __success(task: HRCTask) {
        // 更新状态
        dataProvider.update(task: task, state: .success)
        // 尝试下载下一个
        __beginDownload()
    }

    @objc open func __failed(task: HRCTask) {
        dataProvider.update(task: task, state: .failed)
        __beginDownload()
    }
}

// MARK: - Other

extension HRCDownloder {
    @objc open func receipt(of task: HRCTask) -> HRCDownReceipt? {
        guard task.url.isEmpty == false,
              let receipt = HRCDownloadMaid.oneInstance().downReceipt(forURL: task.url)
        else { return nil }
        return receipt
    }
}

// MARK: /*DMDownload*/

extension HRCDownloder {
    @objc open func beginDMDownload() {
        let dmTasks = dataProvider.underwayTasks.filter { $0.isDummy }
        guard dmTasks.isEmpty == false else {
            cancelTimer()
            return
        }

        dmTasks.forEach {
            dataProvider.update(task: $0, state: .ing)
        }

        cancelTimer()
        dmTimer = DispatchSource.makeTimerSource(flags: .init(rawValue: 0), queue: .global())
        dmTimer?.schedule(deadline: .now(), repeating: .milliseconds(HRCDownloadConfig.yummyDownRefreshDuration))
        dmTimer?.setEventHandler(handler: { [weak self] in
            self?.handleDMProgress()
        })
        dmTimer?.activate()
    }

    @objc open func handleDMProgress() {
        let dmingTasks = dataProvider.underwayTasks.filter { $0.isDummy }
        guard dmingTasks.isEmpty == false else {
            cancelTimer()
            return
        }

        for task in dmingTasks {
            var speed = 0
            let fileSize = task.fileSize == 0 ? 1 : task.fileSize
            var downloadedSize = task.downloadedSize
            var dmStep: HRCDummyStep = .ing
            switch task.state {
            /// 进行中的任务
            case .ing:
                let _progress = Double(downloadedSize) / Double(fileSize)
                let fileSizeLeft = fileSize - downloadedSize
                speed = randomSize(from: HRCDownloadConfig.lowSpeed, to: HRCDownloadConfig.highSpeed)
                downloadedSize += speed
                if _progress >= 0.99 {
                    speed = 0
                    dmStep = .almost99
                    downloadedSize = Int(Double(task.fileSize) * 0.99)
                }

                var averageSpeed: Int = task.dummyAverageSpeed
                if averageSpeed == 0 {
                    averageSpeed = randomSize(from: HRCDownloadConfig.lowSpeed, to: HRCDownloadConfig.highSpeed)
                }
                let targetState: HRCTaskState = dmStep == .almost99 ? .paused : .ing
                let speedStr = ByteCountFormatter.string(fromByteCount: .init(speed), countStyle: .binary)
                dataProvider.update(task: task, state: targetState)
                dataProvider.update(task: task, speed: speedStr, downloadedSize: downloadedSize, dummyStep: dmStep)
            default: break
            }
        }

        let rfTasks = dmingTasks.filter { $0.isDummy && $0.state == .ing }
        if rfTasks.isEmpty {
            cancelTimer()
        }
    }

    @objc open func cancelTimer() {
        dmTimer?.cancel()
        dmTimer = nil
    }

    @objc open func randomSize(from: Int, to: Int) -> Int {
        let gap = abs(to - from)
        if gap == 0 { return 0 }
        let r = Int(arc4random()) % gap + min(from, to)
        return r
    }
}
