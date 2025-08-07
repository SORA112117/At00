//
//  CommonStyles.swift
//  At00
//
//  共通UIスタイル定義
//

import SwiftUI

// MARK: - ボタンスタイルはDesignSystem.swiftで統一管理
// Note: PrimaryButton, SecondaryButton, DestructiveButtonはDesignSystem.swiftで定義

// MARK: - 共通ナビゲーションボタン

struct NavigationCancelButton: View {
    let action: () -> Void
    
    var body: some View {
        Button("キャンセル", action: action)
            .foregroundColor(.secondary)
    }
}

struct NavigationSaveButton: View {
    let action: () -> Void
    let isDisabled: Bool
    
    var body: some View {
        Button("保存", action: action)
            .fontWeight(.semibold)
            .disabled(isDisabled)
    }
}

struct NavigationCloseButton: View {
    let action: () -> Void
    
    var body: some View {
        Button("閉じる", action: action)
            .foregroundColor(.secondary)
    }
}

// MARK: - カードスタイルはDesignSystem.swiftで統一管理
// Note: Card ViewModifierはDesignSystem.swiftで定義

// MARK: - 統一的なアラートメッセージ

struct AlertMessage {
    static let saveError = "データの保存に失敗しました"
    static let loadError = "データの読み込みに失敗しました"
    static let deleteConfirmation = "本当に削除しますか？"
    static let deleteWarning = "この操作は取り消せません"
    static let duplicateRecord = "既に記録されています"
    static let dailyLimitReached = "1日の記録上限に達しました"
}