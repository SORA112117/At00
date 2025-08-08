//
//  MainTabView.swift
//  At00
//
//  メインタブビュー
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var viewModel: AttendanceViewModel
    @State private var showingInitializationError = false
    
    var body: some View {
        ZStack {
            TabView(selection: $viewModel.selectedTab) {
            TimetableView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text(NSLocalizedString("timetable", comment: "Timetable tab title"))
                }
                .tag(0)
                .accessibilityLabel("時間割タブ")
                .accessibilityHint("授業の時間割と出席状況を表示")
            
            EnhancedStatisticsView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text(NSLocalizedString("statistics", comment: "Statistics tab title"))
                }
                .tag(1)
                .accessibilityLabel("統計タブ")
                .accessibilityHint("出席統計とグラフを表示")
            
            SettingsView(shouldNavigateToSheetManagement: $viewModel.shouldNavigateToSheetManagement)
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text(NSLocalizedString("settings", comment: "Settings tab title"))
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
            
            // 初期化中のローディング表示
            if !viewModel.isInitialized {
                ZStack {
                    Color(.systemBackground)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle())
                        
                        Text("データを読み込んでいます...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        if viewModel.initializationError != nil {
                            VStack(spacing: 10) {
                                Text(viewModel.initializationError ?? "")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                Button("再試行") {
                                    viewModel.retryInitialization()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            // 初期化状態をチェック
            checkInitializationStatus()
        }
    }
    
    private func checkInitializationStatus() {
        // 初期化完了を待つ（最大3秒）
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if !viewModel.isInitialized && viewModel.initializationError == nil {
                viewModel.initializationError = "初期化が完了しませんでした。アプリを再起動してください。"
            }
        }
    }
}

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AttendanceViewModel(persistenceController: .preview))
}