//
//  At00App.swift
//  At00
//
//  大学生向け授業欠席管理アプリ
//  Created by 山内壮良 on 2025/08/02.
//

import SwiftUI

@main
struct At00App: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var attendanceViewModel = AttendanceViewModel()
    @State private var showingOnboarding = !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                MainTabView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .environmentObject(attendanceViewModel)
                
                if showingOnboarding {
                    OnboardingView(isPresented: $showingOnboarding)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: showingOnboarding)
        }
    }
}
