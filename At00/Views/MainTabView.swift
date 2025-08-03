//
//  MainTabView.swift
//  At00
//
//  メインタブビュー
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @EnvironmentObject private var viewModel: AttendanceViewModel
    
    var body: some View {
        ZStack {
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
            
            // エラーバナーをトップレベルに表示
            VStack {
                if let errorBanner = viewModel.errorBanner {
                    DesignSystem.ErrorBanner(
                        message: errorBanner.message,
                        type: errorBanner.type,
                        onDismiss: {
                            viewModel.dismissErrorBanner()
                        }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(999)
                }
                
                Spacer()
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.errorBanner?.id)
        }
    }
}

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AttendanceViewModel(persistenceController: .preview))
}