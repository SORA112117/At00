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
    static let semesterDataDidChange = Notification.Name("semesterDataDidChange")
    static let semesterPeriodDidChange = Notification.Name("semesterPeriodDidChange")
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
    @Published var initializationError: String?
    @Published var errorMessage: String?
    @Published var errorBanner: ErrorBannerInfo?
    @Published var currentSemesterType: SemesterType = .firstHalf
    @Published var availableSemesters: [Semester] = []
    
    // タブ遷移管理
    @Published var selectedTab: Int = 0
    @Published var shouldNavigateToSheetManagement = false
    
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
        
        // 初期化処理を同期的に開始（UIの準備を待たない）
        performInitialSetup()
    }
    
    // 同期的な初期化処理
    private func performInitialSetup() {
        print("performInitialSetup: 初期化開始")
        
        // Core Dataの準備が完了してから初期化
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 1. 学期のセットアップ（必須）
            self.setupSemesters()
            
            // 2. 現在の学期を読み込み（setupSemestersの結果に依存）
            self.loadCurrentSemester()
            
            // 3. 時間割を読み込み（currentSemesterに依存）
            // 少し遅延させてCore Dataのコンテキストが完全に準備されるのを待つ
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                if self.currentSemester != nil {
                    print("performInitialSetup: 時間割読み込みを実行")
                    self.loadTimetable()
                }
                
                // 4. 初期化完了
                self.isInitialized = true
                self.initializationError = nil
                self.objectWillChange.send()
                
                print("AttendanceViewModel initialization completed successfully")
                print("Available semesters: \(self.availableSemesters.count)")
                print("Current semester: \(self.currentSemester?.name ?? "none")")
                print("Timetable loaded: \(self.timetable.flatMap { $0 }.compactMap { $0 }.count) courses")
            }
        }
    }
    
    /// 初期化を再試行
    func retryInitialization() {
        isInitialized = false
        initializationError = nil
        performInitialSetup()
    }
    
    /// 欠席数キャッシュ（パフォーマンス最適化）
    @Published var absenceCountCache: [String: Int] = [:]
    
    // MARK: - 統一通知管理システム
    private var pendingNotifications = Set<NotificationName>()
    private var notificationTimer: Timer?
    
    /// 統一通知送信（重複回避・バッチ処理）
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
    
    /// 通知種別の定義
    private enum NotificationName: Hashable {
        case courseData
        case attendanceData
        case statisticsData
        case semesterData
        
        var name: Notification.Name {
            switch self {
            case .courseData: return .courseDataDidChange
            case .attendanceData: return .attendanceDataDidChange
            case .statisticsData: return .statisticsDataDidChange
            case .semesterData: return .semesterDataDidChange
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// 時間割内のすべての授業の欠席数を一括取得（N+1クエリ回避・最適化版）
    func loadAllAbsenceCounts() {
        // 時間割から授業名を効率的に収集
        let courseNames = Set(
            timetable.flatMap { $0 }
                .compactMap { $0?.courseName }
        )
        
        guard !courseNames.isEmpty else {
            DispatchQueue.main.async {
                self.absenceCountCache = [:]
                self.objectWillChange.send()
            }
            return
        }
        
        // バックグラウンドで実行
        backgroundContext.perform {
            let request: NSFetchRequest<AttendanceRecord> = AttendanceRecord.fetchRequest()
            request.predicate = NSPredicate(
                format: "course.courseName IN %@ AND type IN %@",
                Array(courseNames),
                AttendanceType.allCases.filter { $0.affectsCredit }.map { $0.rawValue }
            )
            request.relationshipKeyPathsForPrefetching = ["course"]
            request.sortDescriptors = [NSSortDescriptor(keyPath: \AttendanceRecord.course?.courseName, ascending: true)]
            
            do {
                let allRecords = try self.backgroundContext.fetch(request)
                
                // Dictionary(grouping:by:)を使用した効率的なグループ化
                let groupedRecords = Dictionary(grouping: allRecords) { record in
                    record.course?.courseName ?? ""
                }
                
                var newCache: [String: Int] = [:]
                for courseName in courseNames {
                    newCache[courseName] = groupedRecords[courseName]?.count ?? 0
                }
                
                // メインスレッドでUI更新
                DispatchQueue.main.async {
                    self.absenceCountCache = newCache
                    self.objectWillChange.send()
                }
            } catch {
                self.handleError(error, context: "欠席数一括取得")
                DispatchQueue.main.async {
                    self.absenceCountCache = [:]
                    self.objectWillChange.send()
                }
            }
        }
    }
    
    /// キャッシュから欠席数を取得（N+1クエリ回避）
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
        print("loadCurrentSemester: 開始")
        
        let request: NSFetchRequest<Semester> = Semester.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == true")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Semester.createdAt, ascending: false)]
        request.fetchLimit = 1
        
        do {
            let semesters = try context.fetch(request)
            if let semester = semesters.first {
                DispatchQueue.main.async {
                    self.currentSemester = semester
                    if let typeString = semester.semesterType,
                       let type = SemesterType(rawValue: typeString) {
                        self.currentSemesterType = type
                    }
                    print("loadCurrentSemester: 現在の学期 = \(semester.name ?? "Unknown") [アクティブ]")
                }
            } else {
                print("loadCurrentSemester: アクティブな学期が見つかりません")
                DispatchQueue.main.async {
                    self.showErrorBanner(
                        message: "アクティブな学期が見つかりません。設定から学期を追加してください。",
                        type: .warning
                    )
                }
            }
        } catch {
            print("loadCurrentSemester: エラー = \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "学期データの読み込みに失敗しました: \(error.localizedDescription)"
                self.showErrorBanner(
                    message: "学期情報の読み込みに失敗しました",
                    type: .systemError
                )
            }
        }
    }
    
    /// 時間割を読み込み（パフォーマンス最適化版）
    func loadTimetable() {
        guard let semester = currentSemester else { 
            print("loadTimetable: currentSemesterがnilのため処理をスキップ")
            return 
        }
        
        // セメスターIDを事前に取得（メインコンテキストで）
        let semesterObjectID = semester.objectID
        print("loadTimetable: 学期 '\(semester.name ?? "Unknown")' の時間割を読み込み中")
        
        // 時間割を初期化
        DispatchQueue.main.async {
            self.timetable = Array(repeating: Array(repeating: nil, count: 5), count: 5)
        }
        
        // バックグラウンドで実行
        backgroundContext.perform {
            // バックグラウンドコンテキストでセメスターを再取得
            guard let bgSemester = try? self.backgroundContext.existingObject(with: semesterObjectID) as? Semester else {
                print("loadTimetable: バックグラウンドコンテキストでセメスターを取得できませんでした")
                return
            }
            
            let request: NSFetchRequest<Course> = Course.fetchRequest()
            request.predicate = NSPredicate(format: "semester == %@", bgSemester)
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \Course.period, ascending: true),
                NSSortDescriptor(keyPath: \Course.dayOfWeek, ascending: true)
            ]
            request.propertiesToFetch = ["dayOfWeek", "period", "courseName", "maxAbsences", "colorIndex"]
            
            do {
                let courses = try self.backgroundContext.fetch(request)
                print("loadTimetable: \(courses.count)個のコースを取得")
                
                // メインコンテキストのObjectIDに変換してから時間割に配置
                var courseObjectIDs: [[NSManagedObjectID?]] = Array(repeating: Array(repeating: nil, count: 5), count: 5)
                
                // 効率的な配置（ObjectIDのみ保存）
                for course in courses {
                    let dayIndex = Int(course.dayOfWeek) - 1
                    let periodIndex = Int(course.period) - 1
                    
                    guard dayIndex >= 0, dayIndex < 5, periodIndex >= 0, periodIndex < 5 else {
                        continue
                    }
                    
                    courseObjectIDs[periodIndex][dayIndex] = course.objectID
                }
                
                // メインスレッドでUI更新（メインコンテキストでオブジェクトを再取得）
                DispatchQueue.main.async {
                    var newTimetable: [[Course?]] = Array(repeating: Array(repeating: nil, count: 5), count: 5)
                    
                    for periodIndex in 0..<5 {
                        for dayIndex in 0..<5 {
                            if let objectID = courseObjectIDs[periodIndex][dayIndex],
                               let course = try? self.context.existingObject(with: objectID) as? Course {
                                newTimetable[periodIndex][dayIndex] = course
                            }
                        }
                    }
                    
                    self.timetable = newTimetable
                    print("loadTimetable: 時間割の更新完了")
                    
                    // 時間割読み込み後に欠席数キャッシュも更新
                    self.loadAllAbsenceCounts()
                    
                    // 授業リマインダー通知を更新
                    self.updateClassReminders()
                }
            } catch {
                print("loadTimetable: エラー = \(error)")
                self.handleError(error, context: "時間割の読み込み", critical: true)
            }
        }
    }
    
    // 欠席記録の結果
    enum RecordResult {
        case success
        case alreadyRecorded
        case dailyLimitReached
        case outsideSemesterPeriod
    }
    
    // 欠席を記録（代表的なCourseに1つのみ作成）
    func recordAbsence(for course: Course, type: AttendanceType = .absent, memo: String = "", date: Date = Date()) -> RecordResult {
        guard let courseName = course.courseName else { return .alreadyRecorded }
        
        // 学期の期間内かチェック
        if !isDateWithinCurrentSemesterPeriod(date) {
            return .outsideSemesterPeriod
        }
        
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
        
        // 統一通知システムを使用
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
            
            // 記録を削除
            context.delete(latestRecord)
            
            // Core Dataの保存を安全に実行
            do {
                try context.save()
                print("記録削除成功: \(courseName)")
            } catch {
                print("記録削除保存エラー: \(error)")
                DispatchQueue.main.async {
                    self.errorMessage = "記録の取り消しに失敗しました: \(error.localizedDescription)"
                }
                return
            }
            
            // キャッシュを安全に更新
            DispatchQueue.main.async {
                let newCount = self.getAbsenceCountForCourseName(courseName)
                self.absenceCountCache[courseName] = newCount
                
                // 統一通知システムを使用
                self.scheduleNotification(.attendanceData)
                self.scheduleNotification(.statisticsData)
            }
            
        } catch {
            print("記録削除フェッチエラー: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "記録の取り消しに失敗しました: \(error.localizedDescription)"
            }
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
    
    // 同名科目が既に存在するかチェック（現在の学期内のみ）
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
    
    // 全学期を通じて同名科目が存在するかチェック
    func hasCourseWithSameNameAcrossAllSemesters(_ courseName: String) -> Bool {
        let request: NSFetchRequest<Course> = Course.fetchRequest()
        request.predicate = NSPredicate(format: "courseName == %@", courseName)
        request.fetchLimit = 1
        
        do {
            let count = try context.count(for: request)
            return count > 0
        } catch {
            return false
        }
    }
    
    // 他の学期に同名科目が存在するかチェック（現在の学期を除く）
    func hasCourseWithSameNameInOtherSemesters(_ courseName: String) -> Bool {
        guard let semester = currentSemester else { return false }
        
        let request: NSFetchRequest<Course> = Course.fetchRequest()
        request.predicate = NSPredicate(format: "courseName == %@ AND semester != %@", courseName, semester)
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
    }
    
    // 新しい授業を追加
    func addCourse(name: String, dayOfWeek: Int, period: Int, totalClasses: Int = 15, maxAbsences: Int? = nil, colorIndex: Int = 0) -> AddCourseResult {
        guard let semester = currentSemester else { return .currentSlotOccupied }
        
        // 現在の学期の指定位置に既に授業があるかチェック
        if hasCourseBySemesterAndPosition(semester: semester, dayOfWeek: dayOfWeek, period: period) {
            return .currentSlotOccupied
        }
        
        
        // 現在の学期に授業を追加
        let course = Course(context: context)
        course.courseId = UUID()
        course.courseName = name
        course.dayOfWeek = Int16(dayOfWeek)
        course.period = Int16(period)
        course.totalClasses = Int16(totalClasses)
        course.maxAbsences = Int16(maxAbsences ?? (totalClasses / 3)) // 指定された値を使用、なければデフォルト
        course.semester = semester
        course.isNotificationEnabled = true
        course.colorIndex = Int16(colorIndex)
        
        
        saveContext()
        loadTimetable()
        
        
        // 統一通知システムを使用
        scheduleNotification(.courseData)
        scheduleNotification(.statisticsData)
        
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
    
    
    // 既存授業配置結果
    enum AssignExistingCourseResult {
        case success
        case slotOccupied
        case duplicateNameInSemester
        case duplicateNameAcrossSemesters
    }
    
    // 既存授業を新しい時間割位置に配置
    func assignExistingCourse(course: Course, newDayOfWeek: Int, newPeriod: Int) -> AssignExistingCourseResult {
        guard let semester = currentSemester,
              let courseName = course.courseName else { return .slotOccupied }
        
        // 現在の位置に既に授業があるかチェック
        if hasCourseBySemesterAndPosition(semester: semester, dayOfWeek: newDayOfWeek, period: newPeriod) {
            return .slotOccupied
        }
        
        // 全学期を通じて同名科目が存在するかチェック（ただし、配置元の授業は除く）
        if hasCourseWithSameNameAcrossAllSemesters(courseName) {
            // 現在の学期に既に存在するかチェック
            let currentSemesterRequest: NSFetchRequest<Course> = Course.fetchRequest()
            currentSemesterRequest.predicate = NSPredicate(
                format: "semester == %@ AND courseName == %@ AND courseId != %@",
                semester,
                courseName,
                course.courseId! as CVarArg
            )
            currentSemesterRequest.fetchLimit = 1
            
            do {
                let count = try context.count(for: currentSemesterRequest)
                if count > 0 {
                    // 同じ学期内の異なる時間割に同名授業が既に存在
                    return .duplicateNameInSemester
                }
            } catch {
                print("同名授業チェックエラー: \(error)")
                return .slotOccupied
            }
            
            // 他の学期に存在する場合
            if course.semester != semester {
                return .duplicateNameAcrossSemesters
            }
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
        newCourse.colorIndex = course.colorIndex
        
        // 注意: 欠席記録は代表的なCourse方式により、既存の記録をそのまま参照する
        // 新しい記録のコピーは作成しない（重複を避けるため）
        
        
        saveContext()
        loadTimetable()
        
        // 統一通知システムを使用
        scheduleNotification(.courseData)
        scheduleNotification(.statisticsData)
        
        return .success
    }
    
    
    
    // 授業を削除（同名科目と関連データをすべて削除）
    func deleteCourse(_ course: Course) {
        
        // 単一のコースのみ削除（同名の他のコマは残す）
        context.delete(course)
        saveContext()
        loadTimetable()
        
        // 統一通知システムを使用
        scheduleNotification(.courseData)
        scheduleNotification(.statisticsData)
        scheduleNotification(.attendanceData)
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
            
            // 統一通知システムを使用
            scheduleNotification(.courseData)
            scheduleNotification(.statisticsData)
            scheduleNotification(.attendanceData)
            
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "授業の削除に失敗しました: \(error.localizedDescription)"
            }
        }
    }
    
    // 欠席記録を日付指定で追加（同名科目に完全同期）
    func addAbsenceRecord(for course: Course, date: Date, type: AttendanceType = .absent, memo: String = "手動追加") {
        _ = recordAbsence(for: course, type: type, memo: memo, date: date)
    }
    
    // 指定した日付が現在の学期の期間内かチェック
    func isDateWithinCurrentSemesterPeriod(_ date: Date) -> Bool {
        guard let semester = currentSemester,
              let startDate = semester.startDate,
              let endDate = semester.endDate else {
            return false
        }
        
        let calendar = Calendar.current
        let checkDate = calendar.startOfDay(for: date)
        let semesterStart = calendar.startOfDay(for: startDate)
        let semesterEnd = calendar.startOfDay(for: endDate)
        
        return checkDate >= semesterStart && checkDate <= semesterEnd
    }
    
    // データを保存（外部からアクセス可能）
    func save() {
        saveContext()
        
        // 統一通知システムを使用
        scheduleNotification(.courseData)
        scheduleNotification(.attendanceData)
        scheduleNotification(.statisticsData)
    }
    
    /// 統一的な通知送信メソッド（非推奨：scheduleNotificationを使用）
    @available(*, deprecated, message: "scheduleNotificationを使用してください")
    private func sendDataChangeNotifications() {
        scheduleNotification(.courseData)
        scheduleNotification(.attendanceData)
        scheduleNotification(.statisticsData)
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
            
            // 統一通知システムを使用
            scheduleNotification(.courseData)
            scheduleNotification(.attendanceData)
            scheduleNotification(.statisticsData)
            
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "学期リセットに失敗しました: \(error.localizedDescription)"
            }
        }
    }
    
    // 学期を切り替える
    func switchSemester(to type: SemesterType) {
        DispatchQueue.main.async {
            self.currentSemesterType = type
        }
        loadSemesterByType(type)
        loadTimetable()
    }
    
    // 特定の学期シートに切り替える
    func switchToSemester(_ semester: Semester) {
        guard let targetSemesterId = semester.semesterId else {
            print("switchToSemester エラー: semesterIdが見つかりません")
            return
        }
        
        // ローディング状態を表示
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        // Core Dataから最新のSemesterオブジェクトを取得（参照の整合性を保つため）
        let request: NSFetchRequest<Semester> = Semester.fetchRequest()
        request.predicate = NSPredicate(format: "semesterId == %@", targetSemesterId as CVarArg)
        request.fetchLimit = 1
        
        do {
            guard let freshSemester = try context.fetch(request).first else {
                print("switchToSemester エラー: 指定されたsemesterIdの学期が見つかりません")
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorBanner = ErrorBannerInfo(
                        message: "学期の切り替えに失敗しました",
                        type: .dataNotFound
                    )
                }
                return
            }
            
            // 現在の学期をアクティブでなくする
            if let current = currentSemester {
                current.isActive = false
            }
            
            // 新しい学期をアクティブにする（最新の参照を使用）
            freshSemester.isActive = true
            
            // 変更を一旦保存（アクティブ状態を確実に保存）
            save()
            
            // UI を更新
            DispatchQueue.main.async {
                self.currentSemester = freshSemester
                print("学期切り替え成功: \(freshSemester.name ?? "")")
                
                // 学期タイプも更新
                if let semesterTypeString = freshSemester.semesterType,
                   let semesterType = SemesterType(rawValue: semesterTypeString) {
                    self.currentSemesterType = semesterType
                }
            }
            
            // 時間割を再読み込み（currentSemesterが設定された後）
            DispatchQueue.main.async {
                self.loadTimetable()
                self.loadAllAbsenceCounts() // 欠席数キャッシュも更新
                self.isLoading = false
                
                // 統一通知システムを使用
                self.scheduleNotification(.semesterData)
                self.scheduleNotification(.courseData)
            }
            
        } catch {
            print("switchToSemester エラー: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorBanner = ErrorBannerInfo(
                    message: "学期の切り替えに失敗しました: \(error.localizedDescription)",
                    type: .systemError
                )
            }
        }
    }
    
    // 学期の初期設定
    func setupSemesters() {
        print("setupSemesters: 開始")
        // 現在の学期のIDを保存（更新後も維持するため）
        let currentSemesterIdBeforeSetup = currentSemester?.semesterId
        
        // データベースに学期が存在するかを直接チェック
        let request: NSFetchRequest<Semester> = Semester.fetchRequest()
        request.fetchLimit = 1 // 1つでもあれば十分
        
        do {
            let existingSemesters = try context.fetch(request)
            
            // データベースが完全に空の場合のみデフォルト学期を作成
            if existingSemesters.isEmpty {
                print("データベースが空のため、デフォルト学期を作成します")
                createDefaultSemester()
            } else {
                print("既存の学期が見つかりました（\(existingSemesters.count)個存在）")
            }
            
            // 全ての学期を読み込んでUIを更新
            loadAllSemesters()
            
            // 元の学期が存在していた場合はIDを使って安全に復元
            if let preservedSemesterId = currentSemesterIdBeforeSetup {
                let recoveryRequest: NSFetchRequest<Semester> = Semester.fetchRequest()
                recoveryRequest.predicate = NSPredicate(format: "semesterId == %@", preservedSemesterId as CVarArg)
                recoveryRequest.fetchLimit = 1
                
                if let recoveredSemester = try? context.fetch(recoveryRequest).first {
                    DispatchQueue.main.async {
                        self.currentSemester = recoveredSemester
                        print("setupSemesters後、元の学期(\(recoveredSemester.name ?? ""))をIDベースで安全に回復")
                    }
                } else {
                    print("setupSemesters警告: 元の学期ID(\(preservedSemesterId))が見つかりませんでした")
                }
            }
            
        } catch {
            print("学期チェックエラー: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "学期データの確認に失敗しました: \(error.localizedDescription)"
                self.showErrorBanner(
                    message: "学期データの初期化に失敗しました",
                    type: .systemError
                )
            }
        }
        
        print("setupSemesters: 完了 - \(availableSemesters.count)個の学期が利用可能")
    }
    
    // データベースを完全にリセットして、デフォルト学期のみを作成
    func resetToDefaultSemester() {
        // 全ての既存データを削除
        deleteAllData()
        
        // デフォルト学期を作成
        createDefaultSemester()
        
        // データを再読み込み
        loadAllSemesters()
        loadCurrentSemester()
        loadTimetable()
        
        // 通知を送信
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        print("データベースを初期状態にリセットしました")
    }
    
    // デフォルト学期を作成
    private func createDefaultSemester() {
        let currentSemesterType = getCurrentSemesterType()
        let currentYear = Calendar.current.component(.year, from: Date())
        let semesterName = "\(currentYear)年度\(currentSemesterType == .firstHalf ? "前期" : "後期")"
        
        createSemester(type: currentSemesterType, name: semesterName)
        
        // 確実に保存
        saveContext()
        
        print("デフォルト学期を作成しました: \(semesterName)")
    }
    
    // 全てのデータを削除
    private func deleteAllData() {
        // 出席記録を削除
        let attendanceRequest: NSFetchRequest<NSFetchRequestResult> = AttendanceRecord.fetchRequest()
        let attendanceDeleteRequest = NSBatchDeleteRequest(fetchRequest: attendanceRequest)
        
        // 授業を削除
        let courseRequest: NSFetchRequest<NSFetchRequestResult> = Course.fetchRequest()
        let courseDeleteRequest = NSBatchDeleteRequest(fetchRequest: courseRequest)
        
        // 学期を削除
        let semesterRequest: NSFetchRequest<NSFetchRequestResult> = Semester.fetchRequest()
        let semesterDeleteRequest = NSBatchDeleteRequest(fetchRequest: semesterRequest)
        
        // 時間設定を削除
        let periodTimeRequest: NSFetchRequest<NSFetchRequestResult> = PeriodTime.fetchRequest()
        let periodTimeDeleteRequest = NSBatchDeleteRequest(fetchRequest: periodTimeRequest)
        
        do {
            try context.execute(attendanceDeleteRequest)
            try context.execute(courseDeleteRequest)
            try context.execute(semesterDeleteRequest)
            try context.execute(periodTimeDeleteRequest)
            
            saveContext()
            
            // キャッシュをクリア
            DispatchQueue.main.async {
                self.absenceCountCache.removeAll()
                self.availableSemesters.removeAll()
                self.currentSemester = nil
                self.timetable = Array(repeating: Array(repeating: nil, count: 5), count: 5)
            }
            
            print("全データを削除しました")
        } catch {
            print("データ削除エラー: \(error)")
        }
    }
    
    // 現在の日付に基づいて適切な学期タイプを判定
    private func getCurrentSemesterType() -> SemesterType {
        let calendar = Calendar.current
        let now = Date()
        let month = calendar.component(.month, from: now)
        
        // 4月〜9月: 前期, 10月〜3月: 後期
        if month >= 4 && month <= 9 {
            return .firstHalf
        } else {
            return .secondHalf
        }
    }
    
    // すべての学期を読み込む
    private func loadAllSemesters() {
        let request: NSFetchRequest<Semester> = Semester.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Semester.createdAt, ascending: true)]
        
        do {
            let semesters = try context.fetch(request)
            DispatchQueue.main.async {
                self.availableSemesters = semesters
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "学期データの読み込みに失敗しました: \(error.localizedDescription)"
            }
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
        semester.isActive = true // 初回作成時は常にアクティブに設定
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
                DispatchQueue.main.async {
                    self.currentSemester = semester
                }
                saveContext()
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "学期データの読み込みに失敗しました: \(error.localizedDescription)"
            }
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
            DispatchQueue.main.async {
                self.errorMessage = "データの保存に失敗しました: \(error.localizedDescription)"
            }
            
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
    
    /// 遅延保存（複数の変更を一度に保存）
    private func saveContextDelayed() {
        // 既存のタイマーをキャンセル
        saveTimer?.invalidate()
        
        // 0.5秒後に保存
        saveTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            self.saveContext()
            // 統一通知システムを使用
            self.scheduleNotification(.courseData)
            self.scheduleNotification(.attendanceData)
            self.scheduleNotification(.statisticsData)
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
    
    
    // MARK: - エラーハンドリング強化
    
    /// 統一エラーハンドリング
    private func handleError(_ error: Error, context: String, critical: Bool = false) {
        let errorMessage = "\(context): \(error.localizedDescription)"
        print("Error - \(errorMessage)")
        
        DispatchQueue.main.async {
            self.errorMessage = errorMessage
            
            // クリティカルなエラーの場合はエラーバナーも表示
            if critical {
                self.showErrorBanner(message: errorMessage, type: .error)
            }
        }
        
        // エラー通知を送信
        NotificationCenter.default.post(
            name: .coreDataError,
            object: nil,
            userInfo: ["error": error, "context": context]
        )
    }
    
    /// エラーバナーを表示
    func showErrorBanner(message: String, type: DesignSystem.ErrorBanner.ErrorType) {
        DispatchQueue.main.async {
            self.errorBanner = ErrorBannerInfo(message: message, type: type)
            
            // 自動的にバナーを消去（エラータイプに応じて表示時間を調整）
            let displayDuration: TimeInterval = type == .error ? 8.0 : 5.0
            DispatchQueue.main.asyncAfter(deadline: .now() + displayDuration) {
                if self.errorBanner?.message == message {
                    self.errorBanner = nil
                }
            }
        }
    }
    
    /// エラーバナーを手動で消去
    func dismissErrorBanner() {
        DispatchQueue.main.async {
            self.errorBanner = nil
        }
    }
    
    /// 成功メッセージを表示
    func showSuccessMessage(_ message: String) {
        showErrorBanner(message: message, type: .info)
    }
    
    /// 警告メッセージを表示
    func showWarning(_ message: String) {
        showErrorBanner(message: message, type: .warning)
    }
    
    /// 操作完了フィードバック
    func showOperationSuccess(_ operation: String) {
        showSuccessMessage("\(operation)が完了しました")
        
        // 軽いハプティックフィードバック
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
}