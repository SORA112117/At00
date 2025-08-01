//
//  SemesterType.swift
//  At00
//
//  学期タイプの定義
//

import Foundation

enum SemesterType: String, CaseIterable {
    case firstHalf = "firstHalf"  // 前期
    case secondHalf = "secondHalf"  // 後期
    
    var displayName: String {
        switch self {
        case .firstHalf:
            return "前期"
        case .secondHalf:
            return "後期"
        }
    }
    
    var icon: String {
        switch self {
        case .firstHalf:
            return "1.circle.fill"
        case .secondHalf:
            return "2.circle.fill"
        }
    }
}