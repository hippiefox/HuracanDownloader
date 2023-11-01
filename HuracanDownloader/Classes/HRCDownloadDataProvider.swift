//
//  HRCDownloadDataProvider.swift
//  HuracanDownloader
//
//  Created by pulei yu on 2023/10/26.
//

import Foundation
 
public protocol HRCDownloadDataProvider: NSObject {
    var allTasks: [HRCTask] { get }
    var underwayTasks: [HRCTask] { get }
    var failedTasks: [HRCTask] { get }
    var successTasks: [HRCTask] { get }

    ///  更新下载任务的下载信息，如url地址，header等
    func fetchRealUrl(of task: HRCTask, completion: @escaping (_ updatedTask:HRCTask?) -> Void)

    /// 更新任务状态
    func update(task: HRCTask,state: HRCTaskState)
    
    /// 更新任务速度和大小信息
    func update(task: HRCTask,speed: String,downloadedSize: Int,dummyStep: HRCDummyStep?)
    
    /// 更新任务下载地址
    func update(task: HRCTask,url: String)
    
    /// 需要对url进行transmit
    func taskNeedsTransmit(task: HRCTask)-> URL?
}
