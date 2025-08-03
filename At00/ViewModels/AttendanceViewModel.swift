//
//  AttendanceViewModel.swift
//  At00
//
//  出席管理のメインViewModel
//

import Foundation
import CoreData
import SwiftUI
import UserNotifications

// MARK: - データ更新通知
extension Notification.Name {
    static let attendanceDataDidChange = Notification.Name("attendanceDataDidChange")
    static let courseDataDidChange = Notification.Name("courseDataDidChange")
    static let statisticsDataDidChange = Notification.Name("statisticsDataDidChange")
    static let coreDataError = Notification.Name("coreDataError")
}

// MARK: - エラーバナー情報
struct ErrorBannerInfo: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let type: DesignSystem.ErrorBanner.ErrorType
    let duration: TimeInterval
    
    init(message: String, type: DesignSystem.ErrorBanner.ErrorType, duration: TimeInterval = 5.0) {
        self.message = message
        self.type = type
        self.duration = duration
    }
}

class AttendanceViewModel: ObservableObject {
    @Published var currentSemester: Semester?
    @Published var timetable: [[Course?]] = Array(repeating: Array(repeating: nil, count: 5), count: 5)
    @Published var isLoading = false
    @Published var isInitialized = false
    @Published var errorMessage: String?
    @Published var errorBanner: ErrorBannerInfo?
    @Published var currentSemesterType: SemesterType = .firstHalf
    @Published var availableSemesters: [Semester] = []
    
    let persistenceController: PersistenceController
    private let context: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext
    private let notificationManager = NotificationManager.shared
    
    var managedObjectContext: NSManagedObjectContext {
        return context
    }
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        self.context = persistenceController.container.viewContext
        self.backgroundContext = persistenceController.container.newBackgroundContext()
        
        // 初期化処理をバックグラウンドで実行
        Task {
            await initializeData()
        }
    }
    
    // 非同期初期化処理
    @MainActor
    private func initializeData() async {
        // Core Data操作をバックグラウンドコンテキストで実行
        await backgroundContext.perform {
            self.setupSemesters()
        }
        
        // メインコンテキストでUIデータ読み込み
        await MainActor.run {
            self.loadCurrentSemester()
            self.loadTimetable()
            self.isInitialized = true
            self.objectWillChange.send()
            print("AttendanceViewModel initialization completed")
        }
    }
    
    // 欠席数キャッシュ
    @Published var absenceCountCache: [String: Int] = [:]
    
    // MARK: - 通知管理（重複回避）
    private var pendingNotifications = Set<NotificationName>()
    private var notificationTimer: Timer?
    
    // 統一通知送信（重複回避・バッチ処理）
    private func scheduleNotification(_ notification: NotificationName) {
        pendingNotifications.insert(notification)
        
        // 既存のタイマーをキャンセル
        notificationTimer?.invalidate()
        
        // 短い遅延後にバッチ送信
        notificationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
            self.sendPendingNotifications()
        }
    }
    
    private func sendPendingNotifications() {
        for notification in pendingNotifications {
            NotificationCenter.default.post(name: notification.name, object: nil)
        }
        pendingNotifications.removeAll()
    }
    
    // 通知種別の定義
    private enum NotificationName: Hashable {
        case courseData
        case attendanceData
        case statisticsData
        
        var name: Notification.Name {
            switch self {
            case .courseData: return .courseDataDidChange
            case .attendanceData: return .attendanceDataDidChange
            case .statisticsData: return .statisticsDataDidChange
            }
        }
    }
    
    // MARK: - Public Methods
    
    // 時間割内のすべての授業の欠席数を一括取得（N+1クエリ回避）
    func loadAllAbsenceCounts() {
        // すべての授業名を収集
        var courseNames = Set<String>()
        for row in timetable {
            for course in row {
                if let name = course?.courseName {
                    courseNames.insert(name)
                }
            }
        }
        
        guard !courseNames.isEmpty else {
            DispatchQueue.main.async {
                self.absenceCountCache = [:]
                self.objectWillChange.send()
            }
            return
        }
        
        // 一つのクエリで全ての欠席記録を取得
        let request: NSFetchRequest<AttendanceRecord> = AttendanceRecord.fetchRequest()
        request.predicate = NSPredicate(
            format: "course.courseName IN %@ AND type IN %@",
            Array(courseNames),
            AttendanceType.allCases.filter { $0.affectsCredit }.map { $0.rawValue }
        )
        request.relationshipKeyPathsForPrefetching = ["course"]
        
        do {
            let allRecords = try context.fetch(request)
            
            // メモリ内で授業名ごとにグループ化
            var newCache: [String: Int] = [:]
            for courseName in courseNames {
                newCache[courseName] = 0  // 初期化
            }
            
            for record in allRecords {
                if let courseName = record.course?.courseName {
                    newCache[courseName, default: 0] += 1
                }
            }
            
            // UIの更新はメインスレッドで
            DispatchQueue.main.async {
                self.absenceCountCache = newCache
                self.objectWillChange.send()
            }
        } catch {
            print("欠席数一括取得エラー: \(error)")
            DispatchQueue.main.async {
                self.absenceCountCache = [:]
                self.objectWillChange.send()
            }
        }
    }
    
    // キャッシュから欠席数を取得（N+1クエリ回避）
    func getCachedAbsenceCount(for course: Course) -> Int {
        guard let courseName = course.courseName else { return 0 }
        return absenceCountCache[courseName] ?? getAbsenceCount(for: course)
    }
    
    // 授業名から欠席数を取得（内部用）
    private func getAbsenceCountForCourseName(_ courseName: String) -> Int {
        let sameCourses = getAllCoursesWithSameName(courseName)
        let courseIds = sameCourses.map { $0.objectID }
        
        let request: NSFetchRequest<AttendanceRecord> = AttendanceRecord.fetchRequest()
        request.predicate = NSPredicate(
            format: "course IN %@ AND type IN %@",
            courseIds,
            AttendanceType.allCases.filter { $0.affectsCredit }.map { $0.rawValue }
        )
        
        do {
            return try context.count(for: request)
        } catch {
            print("欠席回数取得エラー: \(error)")
            return 0
        }
    }
    
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
            
            // 時間割読み込み後に欠席数キャッシュも更新
            loadAllAbsenceCounts()
            
            // 授業リマインダー通知を更新
            updateClassReminders()
        } catch {
            errorMessage = "時間割の読み込みに失敗しました: \(error.localizedDescription)"
        }
    }
    
    // 欠席記録の結果
    enum RecordResult {
        case success
        case alreadyRecorded
        case dailyLimitReached
    }
    
    // 欠席を記録（代表的なCourseに1つのみ作成）
    func recordAbsence(for course: Course, type: AttendanceType = .absent, memo: String = "", date: Date = Date()) -> RecordResult {
        guard let courseName = course.courseName else { return .alreadyRecorded }
        
        let calendar = Calendar.current
        _ = calendar.startOfDay(for: date)
        
        // 複数コマ登録の場合の1日上限チェック
        let courseCount = getCourseCountWithSameName(courseName)
        let todayRecordCount = getRecordCountForSameDay(courseName: courseName, date: date)
        
        if todayRecordCount >= courseCount {
            print("同名科目の1日の記録上限に達しています（\(todayRecordCount)/\(courseCount)）")
            return .dailyLimitReached // 上限到達を返す
        }
        
        // 同名科目の代表的なCourse（最初の1つ）に記録を作成
        let sameCourses = getAllCoursesWithSameName(courseName)
        guard let representativeCourse = sameCourses.first else { return .alreadyRecorded }
        
        let record = AttendanceRecord(context: context)
        record.recordId = UUID()
        record.course = representativeCourse
        record.date = date
        record.type = type.rawValue
        record.memo = memo
        record.createdAt = Date()
        
        saveContext()
        
        // キャッシュを更新
        if let courseName = course.courseName {
            let newCount = getAbsenceCountForCourseName(courseName)
            DispatchQueue.main.async {
                self.absenceCountCache[courseName] = newCount
            }
            
            // 欠席上限アラート通知をチェック・送信
            checkAndSendAbsenceLimitNotification(for: course, newAbsenceCount: newCount)
        }
        
        // 統計データの更新を通知（統一システム）
        scheduleNotification(.attendanceData)
        scheduleNotification(.statisticsData)
        
        return .success // 記録成功を返す
    }
    
    // 最後の記録を取り消し（同名科目の最新記録を削除）
    func undoLastRecord(for course: Course) {
        guard let courseName = course.courseName else { return }
        
        // 同名科目の最新記録を1つ取得して削除
        let request: NSFetchRequest<AttendanceRecord> = AttendanceRecord.fetchRequest()
        let sameCourses = getAllCoursesWithSameName(courseName)
        let courseIds = sameCourses.map { $0.objectID }
        
        request.predicate = NSPredicate(
            format: "course IN %@ AND type IN %@",
            courseIds,
            AttendanceType.allCases.filter { $0.affectsCredit }.map { $0.rawValue }
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \AttendanceRecord.date, ascending: false)]
        request.fetchLimit = 1
        
        do {
            let latestRecords = try context.fetch(request)
            guard let latestRecord = latestRecords.first else { 
                print("削除対象の記録が見つかりません: \(courseName)")
                return 
            }
            
            // 削除前に関連データを保存
            let deletedCourse = latestRecord.course
            let wasFullYear = deletedCourse?.isFullYear ?? false
            let recordDate = latestRecord.date
            
            // 記録を削除
            context.delete(latestRecord)
            
            // 通年科目の場合、ペア学期の同じ日付の記録も削除
            if wasFullYear, let deletedCourse = deletedCourse, let recordDate = recordDate {
                deletePairSemesterRecord(course: deletedCourse, date: recordDate)
            }
            
            // Core Dataの保存を安全に実行
            do {
                try context.save()
                print("記録削除成功: \(courseName)")
            } catch {
                print("記録削除保存エラー: \(error)")
                errorMessage = "記録の取り消しに失敗しました: \(error.localizedDescription)"
                return
            }
            
            // キャッシュを安全に更新
            DispatchQueue.main.async {
                let newCount = self.getAbsenceCountForCourseName(courseName)
                self.absenceCountCache[courseName] = newCount
                
                // UI更新の通知を送信（統一システム）
                self.scheduleNotification(.attendanceData)
                self.scheduleNotification(.statisticsData)
            }
            
        } catch {
            print("記録削除フェッチエラー: \(error)")
            errorMessage = "記録の取り消しに失敗しました: \(error.localizedDescription)"
        }
    }
    
    // 通年科目のペア学期の同じ日付の記録を削除
    private func deletePairSemesterRecord(course: Course, date: Date) {
        guard let courseName = course.courseName,
              let currentSemester = course.semester else {
            return
        }
        
        // ペア学期を取得
        guard let pairSemester = findPairSemester(for: currentSemester) else {
            return
        }
        
        // ペア学期の同じ科目を取得
        let pairCourse = getCourseInSemester(
            courseName: courseName,
            dayOfWeek: Int(course.dayOfWeek),
            period: Int(course.period),
            semester: pairSemester
        )
        
        guard let pairCourse = pairCourse else {
            return
        }
        
        // 同じ日付の記録を検索
        let request: NSFetchRequest<AttendanceRecord> = AttendanceRecord.fetchRequest()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            print("日付計算エラー: endOfDay作成失敗")
            return
        }
        
        request.predicate = NSPredicate(
            format: "course == %@ AND date >= %@ AND date < %@",
            pairCourse,
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        
        do {
            let records = try context.fetch(request)
            for record in records {
                context.delete(record)
                print("通年科目ペア記録削除: \(courseName) - \(pairSemester.name ?? "")")
            }
        } catch {
            print("ペア学期記録削除エラー: \(error)")
        }
    }
    
    // 授業の欠席回数を取得（同名科目統合）
    func getAbsenceCount(for course: Course) -> Int {
        guard let courseName = course.courseName else { return 0 }
        
        // 同名科目の全ての記録を取得（代表Course方式なので重複はないはず）
        let sameCourses = getAllCoursesWithSameName(courseName)
        let courseIds = sameCourses.map { $0.objectID }
        
        let request: NSFetchRequest<AttendanceRecord> = AttendanceRecord.fetchRequest()
        request.predicate = NSPredicate(
            format: "course IN %@ AND type IN %@",
            courseIds,
            AttendanceType.allCases.filter { $0.affectsCredit }.map { $0.rawValue }
        )
        
        do {
            return try context.count(for: request)
        } catch {
            print("欠席回数取得エラー: \(error)")
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
    
    // 同名科目が既に存在するかチェック
    func hasCourseWithSameName(_ courseName: String) -> Bool {
        guard let semester = currentSemester else { return false }
        
        let request: NSFetchRequest<Course> = Course.fetchRequest()
        request.predicate = NSPredicate(format: "courseName == %@ AND semester == %@", courseName, semester)
        request.fetchLimit = 1
        
        do {
            let count = try context.count(for: request)
            return count > 0
        } catch {
            return false
        }
    }
    
    // 同名科目の総数を取得
    func getCourseCountWithSameName(_ courseName: String) -> Int {
        guard let semester = currentSemester else { return 0 }
        
        let request: NSFetchRequest<Course> = Course.fetchRequest()
        request.predicate = NSPredicate(format: "courseName == %@ AND semester == %@", courseName, semester)
        
        do {
            return try context.count(for: request)
        } catch {
            return 0
        }
    }
    
    // 指定日に記録された同名科目の欠席記録数を取得
    func getRecordCountForSameDay(courseName: String, date: Date) -> Int {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            print("日付計算エラー: dayEnd作成失敗")
            return 0
        }
        
        let courses = getAllCoursesWithSameName(courseName)
        let courseIds = courses.map { $0.objectID }
        
        let request: NSFetchRequest<AttendanceRecord> = AttendanceRecord.fetchRequest()
        request.predicate = NSPredicate(
            format: "course IN %@ AND date >= %@ AND date < %@ AND type IN %@",
            courseIds,
            dayStart as NSDate,
            dayEnd as NSDate,
            AttendanceType.allCases.filter { $0.affectsCredit }.map { $0.rawValue }
        )
        
        do {
            return try context.count(for: request)
        } catch {
            return 0
        }
    }
    
    // 授業追加結果
    enum AddCourseResult {
        case success
        case currentSlotOccupied
        case otherSemesterSlotOccupied
        case bothSlotsOccupied
    }
    
    // 新しい授業を追加
    func addCourse(name: String, dayOfWeek: Int, period: Int, totalClasses: Int = 15, isFullYear: Bool = false, colorIndex: Int = 0) -> AddCourseResult {
        guard let semester = currentSemester else { return .currentSlotOccupied }
        
        // 現在の学期の指定位置に既に授業があるかチェック
        if hasCourseBySemesterAndPosition(semester: semester, dayOfWeek: dayOfWeek, period: period) {
            return .currentSlotOccupied
        }
        
        // 通年科目の場合、もう一方の学期の同じ位置もチェック
        if isFullYear {
            let otherType: SemesterType = (currentSemesterType == .firstHalf) ? .secondHalf : .firstHalf
            if let otherSemester = availableSemesters.first(where: { $0.semesterType == otherType.rawValue }) {
                if hasCourseBySemesterAndPosition(semester: otherSemester, dayOfWeek: dayOfWeek, period: period) {
                    return .otherSemesterSlotOccupied
                }
            }
        }
        
        // 現在の学期に授業を追加
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
        
        // 通年科目の場合は同期を実行
        if isFullYear {
            syncFullYearCourses()
        }
        
        // コースデータの更新を通知
        NotificationCenter.default.post(name: .courseDataDidChange, object: nil)
        NotificationCenter.default.post(name: .statisticsDataDidChange, object: nil)
        
        return .success
    }
    
    // 指定した学期・位置に既に授業が存在するかチェック
    private func hasCourseBySemesterAndPosition(semester: Semester, dayOfWeek: Int, period: Int) -> Bool {
        let request: NSFetchRequest<Course> = Course.fetchRequest()
        request.predicate = NSPredicate(
            format: "semester == %@ AND dayOfWeek == %@ AND period == %@",
            semester,
            NSNumber(value: dayOfWeek),
            NSNumber(value: period)
        )
        request.fetchLimit = 1
        
        do {
            let count = try context.count(for: request)
            return count > 0
        } catch {
            print("授業存在チェックエラー: \(error)")
            return false
        }
    }
    
    
    // 既存授業を新しい時間割位置に配置
    func assignExistingCourse(course: Course, newDayOfWeek: Int, newPeriod: Int) {
        guard let semester = currentSemester else { return }
        
        // 通年科目で他学期から選択した場合の特別処理
        if course.isFullYear && course.semester != semester {
            assignFullYearCourseFromOtherSemester(course: course, newDayOfWeek: newDayOfWeek, newPeriod: newPeriod)
            return
        }
        
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
        
        // 注意: 欠席記録は代表的なCourse方式により、既存の記録をそのまま参照する
        // 新しい記録のコピーは作成しない（重複を避けるため）
        
        // 通年科目の場合、もう一方の学期にも配置
        if course.isFullYear {
            let otherType: SemesterType = (currentSemesterType == .firstHalf) ? .secondHalf : .firstHalf
            if let otherSemester = availableSemesters.first(where: { $0.semesterType == otherType.rawValue }) {
                // 他学期に同じ位置の授業が既に存在するかチェック
                if !hasExistingCourseInSlot(dayOfWeek: newDayOfWeek, period: newPeriod, semester: otherSemester) {
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
        }
        
        saveContext()
        loadTimetable()
        
        // コースデータの更新を通知
        NotificationCenter.default.post(name: .courseDataDidChange, object: nil)
        NotificationCenter.default.post(name: .statisticsDataDidChange, object: nil)
    }
    
    // 他学期の通年科目を現在の学期に配置する専用メソッド
    private func assignFullYearCourseFromOtherSemester(course: Course, newDayOfWeek: Int, newPeriod: Int) {
        guard let semester = currentSemester,
              let courseName = course.courseName else { return }
        
        print("通年科目データ継承: \(courseName) を他学期から配置")
        
        // 現在の学期に新しい授業を作成（データは共有）
        let newCourse = Course(context: context)
        newCourse.courseId = UUID()
        newCourse.courseName = courseName
        newCourse.dayOfWeek = Int16(newDayOfWeek)
        newCourse.period = Int16(newPeriod)
        newCourse.totalClasses = course.totalClasses
        newCourse.maxAbsences = course.maxAbsences
        newCourse.semester = semester
        newCourse.isNotificationEnabled = course.isNotificationEnabled
        newCourse.isFullYear = true  // 必ず通年科目として設定
        newCourse.colorIndex = course.colorIndex
        
        // 元の授業の設定も通年科目として確実に設定
        course.isFullYear = true
        
        saveContext()
        loadTimetable()
        
        // コースデータの更新を通知
        NotificationCenter.default.post(name: .courseDataDidChange, object: nil)
        NotificationCenter.default.post(name: .statisticsDataDidChange, object: nil)
        
        print("通年科目データ継承完了: \(courseName)")
    }
    
    // 指定された学期のスロットに授業が存在するかチェック
    private func hasExistingCourseInSlot(dayOfWeek: Int, period: Int, semester: Semester) -> Bool {
        let request: NSFetchRequest<Course> = Course.fetchRequest()
        request.predicate = NSPredicate(
            format: "semester == %@ AND dayOfWeek == %@ AND period == %@",
            semester,
            Int16(dayOfWeek),
            Int16(period)
        )
        request.fetchLimit = 1
        
        do {
            let existingCourses = try context.fetch(request)
            return !existingCourses.isEmpty
        } catch {
            print("スロット占有チェックエラー: \(error)")
            return false
        }
    }
    
    // 授業を削除（同名科目と関連データをすべて削除）
    func deleteCourse(_ course: Course) {
        // 通年科目の場合は同期削除を実行
        if course.isFullYear {
            deleteFullYearCourseFromPair(course: course)
        }
        
        // 単一のコースのみ削除（同名の他のコマは残す）
        context.delete(course)
        saveContext()
        loadTimetable()
        
        // コースデータの更新を通知
        NotificationCenter.default.post(name: .courseDataDidChange, object: nil)
        NotificationCenter.default.post(name: .statisticsDataDidChange, object: nil)
        NotificationCenter.default.post(name: .attendanceDataDidChange, object: nil)
    }
    
    // 同名授業をすべて削除する場合の専用メソッド
    func deleteAllCoursesWithSameName(_ course: Course) {
        guard let courseName = course.courseName else {
            deleteCourse(course)
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
            NotificationCenter.default.post(name: .attendanceDataDidChange, object: nil)
            
        } catch {
            errorMessage = "授業の削除に失敗しました: \(error.localizedDescription)"
        }
    }
    
    // 欠席記録を日付指定で追加（同名科目に完全同期）
    func addAbsenceRecord(for course: Course, date: Date, type: AttendanceType = .absent, memo: String = "手動追加") {
        _ = recordAbsence(for: course, type: type, memo: memo, date: date)
    }
    
    // データを保存（外部からアクセス可能）
    func save() {
        saveContext()
        
        // 保存時に関連する通知を送信
        NotificationCenter.default.post(name: .courseDataDidChange, object: nil)
        NotificationCenter.default.post(name: .attendanceDataDidChange, object: nil)
        NotificationCenter.default.post(name: .statisticsDataDidChange, object: nil)
    }
    
    // 統一的な通知送信メソッド
    private func sendDataChangeNotifications() {
        NotificationCenter.default.post(name: .courseDataDidChange, object: nil)
        NotificationCenter.default.post(name: .attendanceDataDidChange, object: nil)
        NotificationCenter.default.post(name: .statisticsDataDidChange, object: nil)
    }
    
    // 指定した学期の時間割をリセット
    func resetSemesterTimetable(for semester: Semester) {
        let courseRequest: NSFetchRequest<Course> = Course.fetchRequest()
        courseRequest.predicate = NSPredicate(format: "semester == %@", semester)
        
        do {
            let courses = try context.fetch(courseRequest)
            
            // 削除対象の科目名を収集
            var courseNamesToDelete = Set<String>()
            for course in courses {
                if let courseName = course.courseName {
                    courseNamesToDelete.insert(courseName)
                }
            }
            
            // 同名科目のすべてのコースと記録を削除（他学期含む）
            for courseName in courseNamesToDelete {
                let allSameCourseRequest: NSFetchRequest<Course> = Course.fetchRequest()
                allSameCourseRequest.predicate = NSPredicate(format: "courseName == %@", courseName)
                
                let allSameCourses = try context.fetch(allSameCourseRequest)
                let allCourseIds = allSameCourses.map { $0.objectID }
                
                // 関連する欠席記録をすべて削除
                let recordRequest: NSFetchRequest<AttendanceRecord> = AttendanceRecord.fetchRequest()
                recordRequest.predicate = NSPredicate(format: "course IN %@", allCourseIds)
                
                let records = try context.fetch(recordRequest)
                for record in records {
                    context.delete(record)
                }
                
                // 同名のすべての授業を削除
                for sameCourse in allSameCourses {
                    context.delete(sameCourse)
                }
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
    
    // 特定の学期シートに切り替える
    func switchToSemester(_ semester: Semester) {
        // 現在の学期をアクティブでなくする
        if let current = currentSemester {
            current.isActive = false
        }
        
        // 新しい学期をアクティブにする
        semester.isActive = true
        currentSemester = semester
        
        // 学期タイプも更新
        if let semesterTypeString = semester.semesterType,
           let semesterType = SemesterType(rawValue: semesterTypeString) {
            currentSemesterType = semesterType
        }
        
        // 時間割を再読み込み
        loadTimetable()
        
        // 変更を保存
        save()
        
        // 通知を送信
        NotificationCenter.default.post(name: .courseDataDidChange, object: nil)
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
    
    // 同名科目の全てのCourseを取得
    private func getAllCoursesWithSameName(_ courseName: String) -> [Course] {
        let request: NSFetchRequest<Course> = Course.fetchRequest()
        request.predicate = NSPredicate(format: "courseName == %@", courseName)
        
        do {
            return try context.fetch(request)
        } catch {
            print("同名科目の取得エラー: \(error)")
            return []
        }
    }
    
    // 指定した科目名・日付範囲に記録が存在するかチェック
    private func hasAbsenceRecord(courseName: String, startDate: Date, endDate: Date) -> Bool {
        let courses = getAllCoursesWithSameName(courseName)
        let courseIds = courses.map { $0.objectID }
        
        let request: NSFetchRequest<AttendanceRecord> = AttendanceRecord.fetchRequest()
        request.predicate = NSPredicate(
            format: "course IN %@ AND date >= %@ AND date < %@ AND type IN %@",
            courseIds,
            startDate as NSDate,
            endDate as NSDate,
            AttendanceType.allCases.filter { $0.affectsCredit }.map { $0.rawValue }
        )
        request.fetchLimit = 1
        
        do {
            let count = try context.count(for: request)
            return count > 0
        } catch {
            print("記録存在チェックエラー: \(error)")
            return false
        }
    }
    
    // 保存タイマー（バッチ保存用）
    private var saveTimer: Timer?
    
    private func saveContext() {
        guard context.hasChanges else { return }
        
        do {
            try context.save()
            print("Core Data保存成功")
        } catch {
            // ロールバック処理を追加
            context.rollback()
            errorMessage = "データの保存に失敗しました: \(error.localizedDescription)"
            
            print("Core Data保存エラー: \(error.localizedDescription)")
            
            // エラーバナーの表示
            showErrorBanner(
                message: "データの保存に失敗しました",
                type: .error
            )
            
            // エラー通知を送信
            NotificationCenter.default.post(
                name: .coreDataError,
                object: nil,
                userInfo: ["error": error]
            )
        }
    }
    
    // 遅延保存（複数の変更を一度に保存）
    private func saveContextDelayed() {
        // 既存のタイマーをキャンセル
        saveTimer?.invalidate()
        
        // 0.5秒後に保存
        saveTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            self.saveContext()
            self.sendDataChangeNotifications()
        }
    }
    
    // MARK: - 通知関連メソッド
    
    /// 欠席上限アラート通知をチェック・送信
    private func checkAndSendAbsenceLimitNotification(for course: Course, newAbsenceCount: Int) {
        guard let courseName = course.courseName else { return }
        
        let maxAbsences = Int(course.maxAbsences)
        let remainingAbsences = max(0, maxAbsences - newAbsenceCount)
        
        // 上限到達または警告範囲（残り2回以下）の場合に通知
        if remainingAbsences <= 2 {
            notificationManager.scheduleAbsenceLimitWarning(
                courseName: courseName,
                currentAbsences: newAbsenceCount,
                maxAbsences: maxAbsences,
                remainingAbsences: remainingAbsences
            )
        }
    }
    
    /// 授業リマインダー通知を更新
    func updateClassReminders() {
        // 現在の時間割から全授業を取得
        var allCourses: [Course] = []
        for row in timetable {
            for course in row {
                if let course = course {
                    allCourses.append(course)
                }
            }
        }
        
        // 授業開始前リマインダーをスケジュール
        notificationManager.scheduleClassReminders(for: allCourses)
    }
    
    /// リマインダー通知設定を更新
    func updateReminderNotifications() {
        notificationManager.scheduleReminderNotifications()
    }
    
    /// 通知権限を確認・リクエスト
    func requestNotificationPermission() async -> Bool {
        return await notificationManager.requestPermission()
    }
    
    /// 全ての通知をキャンセル
    func cancelAllNotifications() {
        notificationManager.cancelAllNotifications()
    }
    
    // MARK: - 通年科目同期機能
    
    /// 通年科目を同期（ペア学期間での科目追加・削除・更新）
    func syncFullYearCourses() {
        // 利用可能な全学期を取得
        let allSemesters = availableSemesters
        
        // 年度別・学期タイプ別にグループ化
        var semesterGroups: [Int: [SemesterType: Semester]] = [:]
        
        for semester in allSemesters {
            guard let semesterTypeString = semester.semesterType,
                  let semesterType = SemesterType(rawValue: semesterTypeString),
                  let startDate = semester.startDate else {
                continue
            }
            
            let year = Calendar.current.component(.year, from: startDate)
            
            if semesterGroups[year] == nil {
                semesterGroups[year] = [:]
            }
            semesterGroups[year]?[semesterType] = semester
        }
        
        // 各年度のペアについて通年科目を同期
        for (_, semesters) in semesterGroups {
            guard let firstHalf = semesters[.firstHalf],
                  let secondHalf = semesters[.secondHalf] else {
                continue // ペアが揃っていない場合はスキップ
            }
            
            syncFullYearCoursesForPair(firstHalf: firstHalf, secondHalf: secondHalf)
        }
    }
    
    /// ペア学期間での通年科目同期
    private func syncFullYearCoursesForPair(firstHalf: Semester, secondHalf: Semester) {
        // 前期の通年科目を取得
        let firstHalfFullYearCourses = getFullYearCourses(for: firstHalf)
        
        // 後期の通年科目を取得
        let secondHalfFullYearCourses = getFullYearCourses(for: secondHalf)
        
        var hasChanges = false
        
        // 前期の通年科目を後期に同期
        for firstHalfCourse in firstHalfFullYearCourses {
            if syncCourseToOtherSemester(course: firstHalfCourse, targetSemester: secondHalf) {
                hasChanges = true
            }
        }
        
        // 後期の通年科目を前期に同期
        for secondHalfCourse in secondHalfFullYearCourses {
            if syncCourseToOtherSemester(course: secondHalfCourse, targetSemester: firstHalf) {
                hasChanges = true
            }
        }
        
        // 変更があった場合のみ保存
        if hasChanges {
            saveContext()
            print("通年科目同期完了: \(firstHalf.name ?? "前期") ⇔ \(secondHalf.name ?? "後期")")
        }
    }
    
    /// 指定学期の通年科目を取得
    private func getFullYearCourses(for semester: Semester) -> [Course] {
        let request: NSFetchRequest<Course> = Course.fetchRequest()
        request.predicate = NSPredicate(format: "semester == %@ AND isFullYear == true", semester)
        
        do {
            return try context.fetch(request)
        } catch {
            print("通年科目取得エラー: \(error)")
            return []
        }
    }
    
    /// 科目を他の学期に同期
    @discardableResult
    private func syncCourseToOtherSemester(course: Course, targetSemester: Semester) -> Bool {
        guard let courseName = course.courseName else { return false }
        
        // 対象学期に同じ科目が既に存在するかチェック
        let existingCourse = getCourseInSemester(
            courseName: courseName,
            dayOfWeek: Int(course.dayOfWeek),
            period: Int(course.period),
            semester: targetSemester
        )
        
        if existingCourse == nil {
            // 存在しない場合は新規作成
            let newCourse = Course(context: context)
            newCourse.courseId = UUID()
            newCourse.courseName = course.courseName
            newCourse.dayOfWeek = course.dayOfWeek
            newCourse.period = course.period
            newCourse.totalClasses = course.totalClasses
            newCourse.maxAbsences = course.maxAbsences
            newCourse.semester = targetSemester
            newCourse.isNotificationEnabled = course.isNotificationEnabled
            newCourse.isFullYear = course.isFullYear
            newCourse.colorIndex = course.colorIndex
            
            print("通年科目同期: \(courseName) を \(targetSemester.name ?? "") に追加")
            return true
        }
        
        return false
    }
    
    /// 指定学期・位置・科目名の科目を取得
    private func getCourseInSemester(courseName: String, dayOfWeek: Int, period: Int, semester: Semester) -> Course? {
        let request: NSFetchRequest<Course> = Course.fetchRequest()
        request.predicate = NSPredicate(
            format: "courseName == %@ AND dayOfWeek == %@ AND period == %@ AND semester == %@",
            courseName,
            NSNumber(value: dayOfWeek),
            NSNumber(value: period),
            semester
        )
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("科目検索エラー: \(error)")
            return nil
        }
    }
    
    /// 通年科目の削除同期
    func deleteFullYearCourseFromPair(course: Course) {
        guard course.isFullYear,
              let courseName = course.courseName,
              let currentSemester = course.semester else {
            return
        }
        
        // ペア学期を見つける
        guard let pairSemester = findPairSemester(for: currentSemester) else {
            return
        }
        
        // ペア学期の同じ科目を削除
        let pairCourse = getCourseInSemester(
            courseName: courseName,
            dayOfWeek: Int(course.dayOfWeek),
            period: Int(course.period),
            semester: pairSemester
        )
        
        if let pairCourse = pairCourse {
            context.delete(pairCourse)
            saveContext()
            print("通年科目同期削除: \(courseName) を \(pairSemester.name ?? "") から削除")
        }
    }
    
    /// ペア学期を検索
    private func findPairSemester(for semester: Semester) -> Semester? {
        guard let semesterTypeString = semester.semesterType,
              let semesterType = SemesterType(rawValue: semesterTypeString),
              let startDate = semester.startDate else {
            return nil
        }
        
        let year = Calendar.current.component(.year, from: startDate)
        let pairSemesterType: SemesterType = (semesterType == .firstHalf) ? .secondHalf : .firstHalf
        
        return availableSemesters.first { otherSemester in
            guard let otherSemesterTypeString = otherSemester.semesterType,
                  let otherSemesterType = SemesterType(rawValue: otherSemesterTypeString),
                  otherSemesterType == pairSemesterType,
                  let otherStartDate = otherSemester.startDate else {
                return false
            }
            
            let otherYear = Calendar.current.component(.year, from: otherStartDate)
            return otherYear == year
        }
    }
    
    // MARK: - エラーハンドリングメソッド
    
    /// エラーバナーを表示
    func showErrorBanner(message: String, type: DesignSystem.ErrorBanner.ErrorType) {
        DispatchQueue.main.async {
            self.errorBanner = ErrorBannerInfo(message: message, type: type)
            
            // 自動的にバナーを消去
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                if self.errorBanner?.message == message {
                    self.errorBanner = nil
                }
            }
        }
    }
    
    /// エラーバナーを手動で消去
    func dismissErrorBanner() {
        errorBanner = nil
    }
    
    /// 成功メッセージを表示
    func showSuccessMessage(_ message: String) {
        showErrorBanner(message: message, type: .info)
    }
    
    /// 警告メッセージを表示
    func showWarning(_ message: String) {
        showErrorBanner(message: message, type: .warning)
    }
}