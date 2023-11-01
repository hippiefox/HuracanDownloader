//
//  HRCDownloadConfig.swift
//  HuracanDownloader
//
//  Created by pulei yu on 2023/10/26.
//

import Foundation
public struct HRCDownloadConfig {
    /// 0: unlimited
    public static var downLimit = 0

    /// down group id
    public static var downGroupId: String = ""

    /// milliseconds
    public static var yummyDownRefreshDuration: Int = 2000

    /// unit: bytes
    public static var lowSpeed: Int = 4 * 1024 * 1024
    
    /// unit: bytes
    public static var highSpeed: Int = 15 * 1024 * 1024
}
