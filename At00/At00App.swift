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
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
