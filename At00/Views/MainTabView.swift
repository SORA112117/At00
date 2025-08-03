//
//  MainTabView.swift
//  At00
//
//  メインタブビュー
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TimetableView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("時間割")
                }
                .tag(0)
                .accessibilityLabel("時間割タブ")
                .accessibilityHint("授業の時間割と出席状況を表示")
            
            EnhancedStatisticsView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("統計")
                }
                .tag(1)
                .accessibilityLabel("統計タブ")
                .accessibilityHint("出席統計とグラフを表示")
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("設定")
                }
                .tag(2)
                .accessibilityLabel("設定タブ")
                .accessibilityHint("アプリの設定を変更")
        }
        .accentColor(.blue)
    }
}

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AttendanceViewModel(persistenceController: .preview))
}