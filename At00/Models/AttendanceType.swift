//
//  AttendanceType.swift
//  At00
//
//  出席記録の種別定義
//

import Foundation

enum AttendanceType: String, CaseIterable {
    case absent = "absent"          // 欠席
    case late = "late"              // 遅刻
    case earlyLeave = "early_leave" // 早退
    case officialAbsent = "official_absent" // 公欠
    
    var displayName: String {
        switch self {
        case .absent:
            return "欠席"
        case .late:
            return "遅刻"
        case .earlyLeave:
            return "早退"
        case .officialAbsent:
            return "公欠"
        }
    }
    
    var emoji: String {
        switch self {
        case .absent:
            return "❌"
        case .late:
            return "⏰"
        case .earlyLeave:
            return "🏃‍♂️"
        case .officialAbsent:
            return "📋"
        }
    }
    
    // 単位に影響するかどうか（欠席のみをカウント）
    var affectsCredit: Bool {
        switch self {
        case .absent:
            return true
        case .late, .earlyLeave, .officialAbsent:
            return false
        }
    }
}