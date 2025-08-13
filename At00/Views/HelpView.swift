//
//  HelpView.swift
//  At00
//
//  ヘルプ・使い方画面
//

import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    private let helpSections = [
        HelpSection(
            icon: "plus.circle.fill",
            title: "時間割の作成",
            items: [
                HelpItem(title: "学期を追加", description: "設定 > 時間割シート管理から新しい学期を追加できます"),
                HelpItem(title: "授業を登録", description: "時間割画面の「+」ボタンから授業を登録しましょう"),
                HelpItem(title: "授業情報設定", description: "授業名、総回数、最大欠席可能回数、色を設定できます")
            ]
        ),
        HelpSection(
            icon: "minus.circle.fill",
            title: "欠席記録",
            items: [
                HelpItem(title: "ワンタップ記録", description: "授業セルをタップすることで欠席記録が追加されます"),
                HelpItem(title: "詳細記録", description: "授業セルを長押しして詳細画面から遅刻・早退・公欠も記録可能"),
                HelpItem(title: "記録の修正", description: "授業詳細画面から過去の記録を編集・削除できます")
            ]
        ),
        HelpSection(
            icon: "paintpalette.fill",
            title: "出席状況の色分け",
            items: [
                HelpItem(title: "緑色", description: "良好な出席状況"),
                HelpItem(title: "オレンジ色", description: "注意が必要（欠席回数が増加）"),
                HelpItem(title: "赤色", description: "危険（上限に近い・超過）")
            ]
        ),
        HelpSection(
            icon: "chart.bar.fill",
            title: "統計機能",
            items: [
                HelpItem(title: "出席率確認", description: "全体の出席率をグラフで確認できます"),
                HelpItem(title: "科目別統計", description: "各科目の詳細な出席状況を確認"),
                HelpItem(title: "危険科目表示", description: "注意が必要な科目を優先的に表示")
            ]
        ),
        HelpSection(
            icon: "bell.fill",
            title: "通知機能",
            items: [
                HelpItem(title: "欠席上限通知", description: "欠席回数が上限に近づいた時にお知らせ"),
                HelpItem(title: "授業開始前通知", description: "授業開始前に出席状況をリマインド"),
                HelpItem(title: "定期リマインダー", description: "設定した時刻に記録の入力を促す通知"),
                HelpItem(title: "通知設定", description: "設定 > 通知設定から詳細にカスタマイズ可能")
            ]
        )
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // ヘッダー
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "graduationcap.fill")
                                .font(.title)
                                .foregroundColor(.blue)
                            
                            Text("とびとびの使い方")
                                .font(.title)
                                .fontWeight(.bold)
                        }
                        
                        Text("とびとびの基本的な使い方をご案内します。")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.leading, 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // ヘルプセクション
                    LazyVStack(spacing: 20) {
                        ForEach(helpSections.indices, id: \.self) { index in
                            HelpSectionView(section: helpSections[index])
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // 追加情報
                    VStack(alignment: .leading, spacing: 16) {
                        Text("その他のヒント")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            TipView(
                                icon: "lightbulb.fill",
                                text: "時間割は複数作成可能です。前期・後期や年度別に管理できます",
                                color: .orange
                            )
                            
                            TipView(
                                icon: "star.fill",
                                text: "授業の色分けで視覚的に管理しやすくなります",
                                color: .yellow
                            )
                            
                            TipView(
                                icon: "shield.fill",
                                text: "データはすべて端末内に保存され、プライバシーが守られます",
                                color: .green
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .overlay(
                // トップバー
                VStack {
                    HStack {
                        Button("完了") {
                            dismiss()
                        }
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.blue)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    Spacer()
                }
            )
        }
    }
}

struct HelpSection {
    let icon: String
    let title: String
    let items: [HelpItem]
}

struct HelpItem {
    let title: String
    let description: String
}

struct HelpSectionView: View {
    let section: HelpSection
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // セクションヘッダー
            HStack(spacing: 12) {
                Image(systemName: section.icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.blue)
                    )
                
                Text(section.title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            // アイテム
            VStack(alignment: .leading, spacing: 12) {
                ForEach(section.items.indices, id: \.self) { index in
                    HelpItemView(item: section.items[index])
                }
            }
            .padding(.leading, 44)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: DesignSystem.adaptiveShadowColor, radius: 4, x: 0, y: 2)
    }
}

struct HelpItemView: View {
    let item: HelpItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
            
            Text(item.description)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct TipView: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    HelpView()
}