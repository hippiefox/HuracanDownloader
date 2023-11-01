//
//  HRCTask.swift
//  HuracanDownloader
//
//  Created by pulei yu on 2023/10/26.
//

import Foundation
import RealmSwift

open class HRCTask: Object {
    @Persisted public var taskId: Int = 0
    @Persisted public var url: String = ""
    @Persisted public var fileSize: Int = 0
    @Persisted public var fileName: String = ""
    @Persisted public var fileSource: String = ""
    @Persisted public var isEncrypted: Bool = false
    /// 组别id
    @Persisted public var groupId: String = ""
    @Persisted public var timestamp: Int = Int(Date().timeIntervalSince1970 * 1000)
    @Persisted public var otherInfo: String = ""
    @Persisted public var headerJSONStr: String = ""
    @Persisted public var etag: String = ""
    /* download progress */
    @Persisted public var state: HRCTaskState = .notStart
    @Persisted public var downloadedSize: Int = 0
    @Persisted public var speedStr: String = ""
    /* Dummy */
    @Persisted public var isDummy: Bool = false
    @Persisted public var dummyStep: HRCDummyStep = .ing
    @Persisted public var dummyAverageSpeed: Int = 0

    public var __needsQueryUrl: Bool { url.isEmpty == true }
    public var __iscl: Bool { etag.count == 40 }

    override open class func primaryKey() -> String? { "taskId" }
}
