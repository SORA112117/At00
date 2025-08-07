//
//  EmptyStateView.swift
//  At00
//
//  空状態表示用のコンポーネント
//

import SwiftUI

struct EmptyStateView: View {
    let imageName: String
    let title: String
    let subtitle: String
    let primaryButtonTitle: String?
    let primaryButtonAction: (() -> Void)?
    let secondaryButtonTitle: String?
    let secondaryButtonAction: (() -> Void)?
    
    init(
        imageName: String,
        title: String,
        subtitle: String,
        primaryButtonTitle: String? = nil,
        primaryButtonAction: (() -> Void)? = nil,
        secondaryButtonTitle: String? = nil,
        secondaryButtonAction: (() -> Void)? = nil
    ) {
        self.imageName = imageName
        self.title = title
        self.subtitle = subtitle
        self.primaryButtonTitle = primaryButtonTitle
        self.primaryButtonAction = primaryButtonAction
        self.secondaryButtonTitle = secondaryButtonTitle
        self.secondaryButtonAction = secondaryButtonAction
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // イラストレーション
            VStack(spacing: 20) {
                Image(systemName: imageName)
                    .font(.system(size: 60, weight: .light))
                    .foregroundColor(.secondary)
                
                VStack(spacing: 8) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }
            }
            
            // ボタンエリア
            if primaryButtonTitle != nil || secondaryButtonTitle != nil {
                VStack(spacing: 12) {
                    if let primaryTitle = primaryButtonTitle,
                       let primaryAction = primaryButtonAction {
                        Button(action: primaryAction) {
                            Text(primaryTitle)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .accessibilityLabel(primaryTitle)
                        .accessibilityHint("主要なアクションを実行します")
                    }
                    
                    if let secondaryTitle = secondaryButtonTitle,
                       let secondaryAction = secondaryButtonAction {
                        Button(action: secondaryAction) {
                            Text(secondaryTitle)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(10)
                        }
                        .accessibilityLabel(secondaryTitle)
                        .accessibilityHint("補助的なアクションを実行します")
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - プリセット空状態ビュー

struct TimetableEmptyStateView: View {
    let onAddCourse: () -> Void
    let onShowHelp: () -> Void
    
    var body: some View {
        EmptyStateView(
            imageName: "calendar.badge.plus",
            title: "時間割を作成しましょう",
            subtitle: "履修している授業を登録して\n出席管理を開始できます",
            primaryButtonTitle: "最初の授業を追加",
            primaryButtonAction: onAddCourse,
            secondaryButtonTitle: "使い方を見る",
            secondaryButtonAction: onShowHelp
        )
    }
}

struct StatisticsEmptyStateView: View {
    let onGoToTimetable: () -> Void
    
    var body: some View {
        EmptyStateView(
            imageName: "chart.bar.xaxis",
            title: "統計データがありません",
            subtitle: "授業を登録して出席記録を付けると\n統計情報が表示されます",
            primaryButtonTitle: "時間割を作成",
            primaryButtonAction: onGoToTimetable
        )
    }
}

struct AbsenceRecordsEmptyStateView: View {
    var body: some View {
        EmptyStateView(
            imageName: "checkmark.circle",
            title: "欠席記録はありません",
            subtitle: "まだ欠席記録がありません。\n今のところ順調に出席できていますね！"
        )
    }
}

struct SemesterEmptyStateView: View {
    let onAddSemester: () -> Void
    
    var body: some View {
        EmptyStateView(
            imageName: "calendar.badge.plus",
            title: "学期を作成してください",
            subtitle: "最初に学期（前期・後期など）を\n作成する必要があります",
            primaryButtonTitle: "学期を追加",
            primaryButtonAction: onAddSemester
        )
    }
}

#Preview("基本形") {
    EmptyStateView(
        imageName: "calendar.badge.plus",
        title: "データがありません",
        subtitle: "まだデータが登録されていません。\n最初のアイテムを追加してみましょう。",
        primaryButtonTitle: "追加",
        primaryButtonAction: {},
        secondaryButtonTitle: "ヘルプ",
        secondaryButtonAction: {}
    )
}

#Preview("時間割空状態") {
    TimetableEmptyStateView(
        onAddCourse: {},
        onShowHelp: {}
    )
}

#Preview("統計空状態") {
    StatisticsEmptyStateView(
        onGoToTimetable: {}
    )
}