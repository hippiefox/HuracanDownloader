//
//  HRCTaskState.swift
//  HuracanDownloader
//
//  Created by pulei yu on 2023/10/26.
//

import Foundation
import RealmSwift

@objc public enum HRCTaskState: Int, RealmEnum, PersistableEnum {
    case notStart = 0
    case waiting
    case ing
    case paused
    case success
    case failed
}

@objc public enum HRCDummyStep: Int, RealmEnum, PersistableEnum {
    case ing = 0
    case almost99
}
