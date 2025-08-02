//
//  AttendanceViewModel.swift
//  At00
//
//  出席管理のメインViewModel
//

import Foundation
import CoreData
import SwiftUI

// MARK: - データ更新通知
extension Notification.Name {
    static let attendanceDataDidChange = Notification.Name("attendanceDataDidChange")
    static let courseDataDidChange = Notification.Name("courseDataDidChange")
    static let statisticsDataDidChange = Notification.Name("statisticsDataDidChange")
}

class AttendanceViewModel: ObservableObject {
    @Published var currentSemester: Semester?
    @Published var timetable: [[Course?]] = Array(repeating: Array(repeating: nil, count: 5), count: 5)
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentSemesterType: SemesterType = .firstHalf
    @Published var availableSemesters: [Semester] = []
    
    let persistenceController: PersistenceController
    private let context: NSManagedObjectContext
    
    var managedObjectContext: NSManagedObjectContext {
        return context
    }
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        self.context = persistenceController.container.viewContext
        setupSemesters()
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
            if let semester = semesters.first {
                currentSemester = semester
                if let typeString = semester.semesterType,
                   let type = SemesterType(rawValue: typeString) {
                    currentSemesterType = type
                }
            }
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
    
    // 欠席を記録（同一名授業にも同期）
    func recordAbsence(for course: Course, type: AttendanceType = .absent, memo: String = "") {
        guard let courseName = course.courseName, 
              let semester = course.semester else { return }
        
        // 同一名の全ての授業を取得
        let request: NSFetchRequest<Course> = Course.fetchRequest()
        request.predicate = NSPredicate(format: "courseName == %@ AND semester == %@", courseName, semester)
        
        do {
            let sameCourses = try context.fetch(request)
            
            // 同一名の全ての授業に欠席記録を追加
            for sameCourse in sameCourses {
                let record = AttendanceRecord(context: context)
                record.recordId = UUID()
                record.course = sameCourse
                record.date = Date()
                record.type = type.rawValue
                record.memo = memo
                record.createdAt = Date()
            }
            
            saveContext()
            
            // 統計データの更新を通知
            NotificationCenter.default.post(name: .attendanceDataDidChange, object: nil)
            NotificationCenter.default.post(name: .statisticsDataDidChange, object: nil)
        } catch {
            errorMessage = "欠席記録の保存に失敗しました: \(error.localizedDescription)"
        }
    }
    
    // 最後の記録を取り消し（同一名授業からも同期）
    func undoLastRecord(for course: Course) {
        guard let courseName = course.courseName,
              let semester = course.semester else { return }
        
        // 同一名の全ての授業を取得
        let courseRequest: NSFetchRequest<Course> = Course.fetchRequest()
        courseRequest.predicate = NSPredicate(format: "courseName == %@ AND semester == %@", courseName, semester)
        
        do {
            let sameCourses = try context.fetch(courseRequest)
            
            // 同一名授業の最新記録を取得して削除
            for sameCourse in sameCourses {
                let request: NSFetchRequest<AttendanceRecord> = AttendanceRecord.fetchRequest()
                request.predicate = NSPredicate(format: "course == %@", sameCourse)
                request.sortDescriptors = [NSSortDescriptor(keyPath: \AttendanceRecord.createdAt, ascending: false)]
                request.fetchLimit = 1
                
                let records = try context.fetch(request)
                if let lastRecord = records.first {
                    context.delete(lastRecord)
                }
            }
            
            saveContext()
            
            // 統計データの更新を通知
            NotificationCenter.default.post(name: .attendanceDataDidChange, object: nil)
            NotificationCenter.default.post(name: .statisticsDataDidChange, object: nil)
        } catch {
            errorMessage = "記録の取り消しに失敗しました: \(error.localizedDescription)"
        }
    }
    
    // 授業の欠席回数を取得
    func getAbsenceCount(for course: Course) -> Int {
        // 通年科目の場合は前期・後期両方の欠席記録を合算
        if course.isFullYear, let courseName = course.courseName {
            let request: NSFetchRequest<AttendanceRecord> = AttendanceRecord.fetchRequest()
            
            // 同じ名前の全ての授業（前期・後期含む）の欠席記録を取得
            let courseRequest: NSFetchRequest<Course> = Course.fetchRequest()
            courseRequest.predicate = NSPredicate(format: "courseName == %@", courseName)
            
            do {
                let allCourses = try context.fetch(courseRequest)
                let courseIds = allCourses.map { $0.objectID }
                
                request.predicate = NSPredicate(
                    format: "course IN %@ AND type IN %@",
                    courseIds,
                    AttendanceType.allCases.filter { $0.affectsCredit }.map { $0.rawValue }
                )
                
                return try context.count(for: request)
            } catch {
                return 0
            }
        } else {
            // 通常科目の場合は従来通り
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
    func addCourse(name: String, dayOfWeek: Int, period: Int, totalClasses: Int = 15, isFullYear: Bool = false, colorIndex: Int = 0) {
        guard let semester = currentSemester else { return }
        
        // 同名の既存授業を確認して欠席記録を取得
        let existingRecords = getExistingAbsenceRecords(for: name, in: semester)
        
        let course = Course(context: context)
        course.courseId = UUID()
        course.courseName = name
        course.dayOfWeek = Int16(dayOfWeek)
        course.period = Int16(period)
        course.totalClasses = Int16(totalClasses)
        course.maxAbsences = Int16(totalClasses / 3) // デフォルト: 1/3まで欠席可能
        course.semester = semester
        course.isNotificationEnabled = true
        course.isFullYear = isFullYear
        course.colorIndex = Int16(colorIndex)
        
        // 既存の欠席記録を新しい授業にも適用
        for record in existingRecords {
            let newRecord = AttendanceRecord(context: context)
            newRecord.recordId = UUID()
            newRecord.course = course
            newRecord.date = record.date
            newRecord.type = record.type
            newRecord.memo = record.memo
            newRecord.createdAt = record.createdAt
        }
        
        // 通年科目の場合、もう一方の学期にも同じ授業を追加
        if isFullYear {
            let otherType: SemesterType = (currentSemesterType == .firstHalf) ? .secondHalf : .firstHalf
            if let otherSemester = availableSemesters.first(where: { $0.semesterType == otherType.rawValue }) {
                let otherCourse = Course(context: context)
                otherCourse.courseId = UUID()
                otherCourse.courseName = name
                otherCourse.dayOfWeek = Int16(dayOfWeek)
                otherCourse.period = Int16(period)
                otherCourse.totalClasses = Int16(totalClasses)
                otherCourse.maxAbsences = Int16(totalClasses / 3)
                otherCourse.semester = otherSemester
                otherCourse.isNotificationEnabled = true
                otherCourse.isFullYear = isFullYear
                otherCourse.colorIndex = Int16(colorIndex)
            }
        }
        
        saveContext()
        loadTimetable()
        
        // コースデータの更新を通知
        NotificationCenter.default.post(name: .courseDataDidChange, object: nil)
        NotificationCenter.default.post(name: .statisticsDataDidChange, object: nil)
    }
    
    // 同名授業の既存欠席記録を取得
    private func getExistingAbsenceRecords(for courseName: String, in semester: Semester) -> [AttendanceRecord] {
        let courseRequest: NSFetchRequest<Course> = Course.fetchRequest()
        courseRequest.predicate = NSPredicate(format: "courseName == %@ AND semester == %@", courseName, semester)
        courseRequest.fetchLimit = 1
        
        do {
            let courses = try context.fetch(courseRequest)
            guard let existingCourse = courses.first else { return [] }
            
            let recordRequest: NSFetchRequest<AttendanceRecord> = AttendanceRecord.fetchRequest()
            recordRequest.predicate = NSPredicate(format: "course == %@", existingCourse)
            recordRequest.sortDescriptors = [NSSortDescriptor(keyPath: \AttendanceRecord.createdAt, ascending: true)]
            
            return try context.fetch(recordRequest)
        } catch {
            return []
        }
    }
    
    // 既存授業を新しい時間割位置に配置
    func assignExistingCourse(course: Course, newDayOfWeek: Int, newPeriod: Int) {
        guard let semester = currentSemester,
              let courseName = course.courseName else { return }
        
        // 同名の既存授業の欠席記録を取得
        let existingRecords = getExistingAbsenceRecords(for: courseName, in: semester)
        
        // 既存の授業の複製を作成
        let newCourse = Course(context: context)
        newCourse.courseId = UUID()
        newCourse.courseName = course.courseName
        newCourse.dayOfWeek = Int16(newDayOfWeek)
        newCourse.period = Int16(newPeriod)
        newCourse.totalClasses = course.totalClasses
        newCourse.maxAbsences = course.maxAbsences
        newCourse.semester = semester
        newCourse.isNotificationEnabled = course.isNotificationEnabled
        newCourse.isFullYear = course.isFullYear
        newCourse.colorIndex = course.colorIndex
        
        // 既存の欠席記録を新しい授業にも適用
        for record in existingRecords {
            let newRecord = AttendanceRecord(context: context)
            newRecord.recordId = UUID()
            newRecord.course = newCourse
            newRecord.date = record.date
            newRecord.type = record.type
            newRecord.memo = record.memo
            newRecord.createdAt = record.createdAt
        }
        
        // 通年科目の場合、もう一方の学期にも配置
        if course.isFullYear {
            let otherType: SemesterType = (currentSemesterType == .firstHalf) ? .secondHalf : .firstHalf
            if let otherSemester = availableSemesters.first(where: { $0.semesterType == otherType.rawValue }) {
                let otherCourse = Course(context: context)
                otherCourse.courseId = UUID()
                otherCourse.courseName = course.courseName
                otherCourse.dayOfWeek = Int16(newDayOfWeek)
                otherCourse.period = Int16(newPeriod)
                otherCourse.totalClasses = course.totalClasses
                otherCourse.maxAbsences = course.maxAbsences
                otherCourse.semester = otherSemester
                otherCourse.isNotificationEnabled = course.isNotificationEnabled
                otherCourse.isFullYear = course.isFullYear
                otherCourse.colorIndex = course.colorIndex
            }
        }
        
        saveContext()
        loadTimetable()
        
        // コースデータの更新を通知
        NotificationCenter.default.post(name: .courseDataDidChange, object: nil)
        NotificationCenter.default.post(name: .statisticsDataDidChange, object: nil)
    }
    
    // 授業を削除（同名科目と関連データをすべて削除）
    func deleteCourse(_ course: Course) {
        guard let courseName = course.courseName else {
            // 単一のコースのみ削除
            context.delete(course)
            saveContext()
            loadTimetable()
            
            // コースデータの更新を通知
            NotificationCenter.default.post(name: .courseDataDidChange, object: nil)
            NotificationCenter.default.post(name: .statisticsDataDidChange, object: nil)
            return
        }
        
        // 同名の全ての授業を取得
        let courseRequest: NSFetchRequest<Course> = Course.fetchRequest()
        courseRequest.predicate = NSPredicate(format: "courseName == %@", courseName)
        
        do {
            let sameCourses = try context.fetch(courseRequest)
            let courseIds = sameCourses.map { $0.objectID }
            
            // 関連する欠席記録をすべて削除
            let recordRequest: NSFetchRequest<AttendanceRecord> = AttendanceRecord.fetchRequest()
            recordRequest.predicate = NSPredicate(format: "course IN %@", courseIds)
            
            let records = try context.fetch(recordRequest)
            for record in records {
                context.delete(record)
            }
            
            // 同名の全ての授業を削除
            for sameCourse in sameCourses {
                context.delete(sameCourse)
            }
            
            saveContext()
            loadTimetable()
            
            // コースデータの更新を通知
            NotificationCenter.default.post(name: .courseDataDidChange, object: nil)
            NotificationCenter.default.post(name: .statisticsDataDidChange, object: nil)
            
        } catch {
            errorMessage = "授業の削除に失敗しました: \(error.localizedDescription)"
        }
    }
    
    // データを保存（外部からアクセス可能）
    func save() {
        saveContext()
    }
    
    // 指定した学期の時間割をリセット
    func resetSemesterTimetable(for semester: Semester) {
        let courseRequest: NSFetchRequest<Course> = Course.fetchRequest()
        courseRequest.predicate = NSPredicate(format: "semester == %@", semester)
        
        do {
            let courses = try context.fetch(courseRequest)
            let courseIds = courses.map { $0.objectID }
            
            // 該当学期の欠席記録をすべて削除
            let recordRequest: NSFetchRequest<AttendanceRecord> = AttendanceRecord.fetchRequest()
            recordRequest.predicate = NSPredicate(format: "course IN %@", courseIds)
            
            let records = try context.fetch(recordRequest)
            for record in records {
                context.delete(record)
            }
            
            // 該当学期の授業をすべて削除
            for course in courses {
                context.delete(course)
            }
            
            saveContext()
            loadTimetable()
            
            // コースデータの更新を通知
            NotificationCenter.default.post(name: .courseDataDidChange, object: nil)
            NotificationCenter.default.post(name: .attendanceDataDidChange, object: nil)
            NotificationCenter.default.post(name: .statisticsDataDidChange, object: nil)
            
        } catch {
            errorMessage = "学期リセットに失敗しました: \(error.localizedDescription)"
        }
    }
    
    // 学期を切り替える
    func switchSemester(to type: SemesterType) {
        currentSemesterType = type
        loadSemesterByType(type)
        loadTimetable()
    }
    
    // 学期の初期設定
    func setupSemesters() {
        loadAllSemesters()
        
        // 前期・後期の学期がなければ作成
        if !hasSemester(of: .firstHalf) {
            createSemester(type: .firstHalf, name: "2025年度前期")
        }
        if !hasSemester(of: .secondHalf) {
            createSemester(type: .secondHalf, name: "2025年度後期")
        }
        
        loadAllSemesters()
    }
    
    // すべての学期を読み込む
    private func loadAllSemesters() {
        let request: NSFetchRequest<Semester> = Semester.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Semester.createdAt, ascending: true)]
        
        do {
            availableSemesters = try context.fetch(request)
        } catch {
            errorMessage = "学期データの読み込みに失敗しました: \(error.localizedDescription)"
        }
    }
    
    // 特定タイプの学期が存在するか確認
    private func hasSemester(of type: SemesterType) -> Bool {
        availableSemesters.contains { semester in
            semester.semesterType == type.rawValue
        }
    }
    
    // 学期を作成
    private func createSemester(type: SemesterType, name: String) {
        let semester = Semester(context: context)
        semester.semesterId = UUID()
        semester.name = name
        semester.semesterType = type.rawValue
        semester.isActive = (type == .firstHalf) // デフォルトは前期をアクティブに
        semester.createdAt = Date()
        
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        
        switch type {
        case .firstHalf:
            semester.startDate = calendar.date(from: DateComponents(year: year, month: 4, day: 1)) ?? Date()
            semester.endDate = calendar.date(from: DateComponents(year: year, month: 9, day: 30)) ?? Date()
        case .secondHalf:
            semester.startDate = calendar.date(from: DateComponents(year: year, month: 10, day: 1)) ?? Date()
            semester.endDate = calendar.date(from: DateComponents(year: year + 1, month: 3, day: 31)) ?? Date()
        }
        
        saveContext()
    }
    
    // 特定タイプの学期を読み込む
    private func loadSemesterByType(_ type: SemesterType) {
        let request: NSFetchRequest<Semester> = Semester.fetchRequest()
        request.predicate = NSPredicate(format: "semesterType == %@", type.rawValue)
        request.fetchLimit = 1
        
        do {
            let semesters = try context.fetch(request)
            if let semester = semesters.first {
                // 古いアクティブ学期を非アクティブに
                availableSemesters.forEach { $0.isActive = false }
                
                // 新しい学期をアクティブに
                semester.isActive = true
                currentSemester = semester
                saveContext()
            }
        } catch {
            errorMessage = "学期データの読み込みに失敗しました: \(error.localizedDescription)"
        }
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