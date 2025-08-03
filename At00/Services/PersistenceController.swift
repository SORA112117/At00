//
//  PersistenceController.swift
//  At00
//
//  大学生向け授業欠席管理アプリ - Core Data管理
//

import CoreData
import Foundation

class PersistenceController: ObservableObject {
    static let shared = PersistenceController()
    
    // プレビュー用のインメモリストア
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // プレビュー用のサンプルデータを作成
        let semester = Semester(context: viewContext)
        semester.semesterId = UUID()
        semester.name = "2024年度 前期"
        semester.startDate = Calendar.current.date(from: DateComponents(year: 2024, month: 4, day: 1)) ?? Date()
        semester.endDate = Calendar.current.date(from: DateComponents(year: 2024, month: 7, day: 31)) ?? Date()
        semester.isActive = true
        semester.createdAt = Date()
        
        // サンプル授業を作成
        let course1 = Course(context: viewContext)
        course1.courseId = UUID()
        course1.courseName = "プログラミング基礎"
        course1.dayOfWeek = 1 // 月曜日
        course1.period = 1 // 1限
        course1.totalClasses = 15
        course1.maxAbsences = 5
        course1.semester = semester
        
        let course2 = Course(context: viewContext)
        course2.courseId = UUID()
        course2.courseName = "データ構造"
        course2.dayOfWeek = 2 // 火曜日
        course2.period = 2 // 2限
        course2.totalClasses = 15
        course2.maxAbsences = 5
        course2.semester = semester
        
        try? viewContext.save()
        return result
    }()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "AttendanceModel")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                print("Core Data error: \(error), \(error.userInfo)")
                // エラーを通知
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .coreDataError,
                        object: nil,
                        userInfo: ["error": error]
                    )
                }
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    // データの保存
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                print("Core Data save error: \(nsError), \(nsError.userInfo)")
                // エラーを通知
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .coreDataError,
                        object: nil,
                        userInfo: ["error": nsError]
                    )
                }
            }
        }
    }
}