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
            
            RiskManagementView()
                .tabItem {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("危険度")
                }
                .tag(1)
            
            EnhancedStatisticsView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("統計")
                }
                .tag(2)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("設定")
                }
                .tag(3)
        }
        .accentColor(.blue)
    }
}

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}