//
//  AttendanceViewModel.swift
//  At00
//
//  出席管理のメインViewModel
//

import Foundation
import CoreData
import SwiftUI

class AttendanceViewModel: ObservableObject {
    @Published var currentSemester: Semester?
    @Published var timetable: [[Course?]] = Array(repeating: Array(repeating: nil, count: 5), count: 5)
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    let persistenceController: PersistenceController
    private let context: NSManagedObjectContext
    
    var managedObjectContext: NSManagedObjectContext {
        return context
    }
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        self.context = persistenceController.container.viewContext
        loadCurrentSemester()
        loadTimetable()
    }
    
    // MARK: - Public Methods
    
    // 現在の学期を読み込み
    func loadCurrentSemester() {
        let request: NSFetchRequest<Semester> = Semester.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == true")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Semester.createdAt, ascending: false)]
        request.fetchLimit = 1
        
        do {
            let semesters = try context.fetch(request)
            currentSemester = semesters.first
        } catch {
            errorMessage = "学期データの読み込みに失敗しました: \(error.localizedDescription)"
        }
    }
    
    // 時間割を読み込み
    func loadTimetable() {
        guard let semester = currentSemester else { return }
        
        // 時間割を初期化
        timetable = Array(repeating: Array(repeating: nil, count: 5), count: 5)
        
        let request: NSFetchRequest<Course> = Course.fetchRequest()
        request.predicate = NSPredicate(format: "semester == %@", semester)
        
        do {
            let courses = try context.fetch(request)
            
            for course in courses {
                let dayIndex = Int(course.dayOfWeek) - 1 // 0-based index
                let periodIndex = Int(course.period) - 1 // 0-based index
                
                if dayIndex >= 0 && dayIndex < 5 && periodIndex >= 0 && periodIndex < 5 {
                    timetable[periodIndex][dayIndex] = course
                }
            }
        } catch {
            errorMessage = "時間割の読み込みに失敗しました: \(error.localizedDescription)"
        }
    }
    
    // 欠席を記録
    func recordAbsence(for course: Course, type: AttendanceType = .absent, memo: String = "") {
        let record = AttendanceRecord(context: context)
        record.recordId = UUID()
        record.course = course
        record.date = Date()
        record.type = type.rawValue
        record.memo = memo
        record.createdAt = Date()
        
        saveContext()
    }
    
    // 最後の記録を取り消し
    func undoLastRecord(for course: Course) {
        let request: NSFetchRequest<AttendanceRecord> = AttendanceRecord.fetchRequest()
        request.predicate = NSPredicate(format: "course == %@", course)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \AttendanceRecord.createdAt, ascending: false)]
        request.fetchLimit = 1
        
        do {
            let records = try context.fetch(request)
            if let lastRecord = records.first {
                context.delete(lastRecord)
                saveContext()
            }
        } catch {
            errorMessage = "記録の取り消しに失敗しました: \(error.localizedDescription)"
        }
    }
    
    // 授業の欠席回数を取得
    func getAbsenceCount(for course: Course) -> Int {
        let request: NSFetchRequest<AttendanceRecord> = AttendanceRecord.fetchRequest()
        request.predicate = NSPredicate(format: "course == %@ AND type IN %@", 
                                      course, 
                                      AttendanceType.allCases.filter { $0.affectsCredit }.map { $0.rawValue })
        
        do {
            return try context.count(for: request)
        } catch {
            return 0
        }
    }
    
    // 残り欠席可能回数を取得
    func getRemainingAbsences(for course: Course) -> Int {
        let currentAbsences = getAbsenceCount(for: course)
        let maxAbsences = Int(course.maxAbsences)
        return max(0, maxAbsences - currentAbsences)
    }
    
    // 出席状況の色を取得
    func getStatusColor(for course: Course) -> Color {
        let remaining = getRemainingAbsences(for: course)
        
        if remaining <= 0 {
            return .red // 単位危険
        } else if remaining <= 2 {
            return .orange // 注意
        } else {
            return .green // 余裕あり
        }
    }
    
    // 新しい授業を追加
    func addCourse(name: String, dayOfWeek: Int, period: Int, totalClasses: Int = 15) {
        guard let semester = currentSemester else { return }
        
        let course = Course(context: context)
        course.courseId = UUID()
        course.courseName = name
        course.dayOfWeek = Int16(dayOfWeek)
        course.period = Int16(period)
        course.totalClasses = Int16(totalClasses)
        course.maxAbsences = Int16(totalClasses / 3) // デフォルト: 1/3まで欠席可能
        course.semester = semester
        course.isNotificationEnabled = true
        
        saveContext()
        loadTimetable()
    }
    
    // 授業を削除
    func deleteCourse(_ course: Course) {
        context.delete(course)
        saveContext()
        loadTimetable()
    }
    
    // データを保存（外部からアクセス可能）
    func save() {
        saveContext()
    }
    
    // MARK: - Private Methods
    
    private func saveContext() {
        do {
            try context.save()
        } catch {
            errorMessage = "データの保存に失敗しました: \(error.localizedDescription)"
        }
    }
}