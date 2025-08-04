//
//  StatisticsView.swift
//  At00
//
//  統計表示画面
//

import SwiftUI
import Charts
import CoreData

struct StatisticsView: View {
    @EnvironmentObject private var viewModel: AttendanceViewModel
    @State private var selectedPeriod: StatisticsPeriod = .thisWeek
    @State private var selectedSemesterForStats: Semester? = nil
    @State private var coursesForSelectedSemester: [Course] = []
    @State private var isLoading = false
    
    enum StatisticsPeriod: String, CaseIterable {
        case thisWeek = "今週"
        case thisMonth = "今月"
        case thisSemester = "今学期"
        
        var dateRange: (start: Date, end: Date) {
            let calendar = Calendar.current
            let now = Date()
            
            switch self {
            case .thisWeek:
                let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
                let endOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.end ?? now
                return (startOfWeek, endOfWeek)
            case .thisMonth:
                let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
                let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end ?? now
                return (startOfMonth, endOfMonth)
            case .thisSemester:
                // 学期の開始・終了日を使用
                return (Date().addingTimeInterval(-86400 * 120), Date()) // 仮の120日前から現在まで
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 統計用シート選択
                    VStack(alignment: .leading, spacing: 12) {
                        Text("統計対象シート")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Menu {
                            ForEach(viewModel.availableSemesters, id: \.semesterId) { semester in
                                Button(action: {
                                    selectSemesterForStats(semester)
                                }) {
                                    HStack {
                                        Text(semester.name ?? "")
                                        Spacer()
                                        if selectedSemesterForStats?.semesterId == semester.semesterId {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "chart.bar.doc.horizontal")
                                    .foregroundColor(.blue)
                                Text(selectedSemesterForStats?.name ?? "シートを選択")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                    }
                    
                    if selectedSemesterForStats != nil {
                        // 期間選択
                        Picker("期間", selection: $selectedPeriod) {
                            ForEach(StatisticsPeriod.allCases, id: \.self) { period in
                                Text(period.rawValue).tag(period)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                        
                        // 全体サマリー
                        VStack(alignment: .leading, spacing: 16) {
                            Text("出席状況サマリー")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                                SummaryCard(
                                    title: "総授業数",
                                    value: "\(coursesForSelectedSemester.count)",
                                    subtitle: "科目",
                                    color: .blue,
                                    icon: "book.fill"
                                )
                                
                                SummaryCard(
                                    title: "今週の欠席",
                                    value: "\(getWeeklyAbsenceCount())",
                                    subtitle: "回",
                                    color: .red,
                                    icon: "exclamationmark.triangle.fill"
                                )
                                
                                SummaryCard(
                                    title: "出席率",
                                    value: "\(Int(getAverageAttendanceRate()))%",
                                    subtitle: "平均",
                                    color: .green,
                                    icon: "chart.line.uptrend.xyaxis"
                                )
                                
                                SummaryCard(
                                    title: "注意科目",
                                    value: "\(getWarningCoursesCount())",
                                    subtitle: "科目",
                                    color: .orange,
                                    icon: "exclamationmark.circle.fill"
                                )
                            }
                            .padding(.horizontal)
                        }
                        
                        // 授業別出席状況
                        VStack(alignment: .leading, spacing: 16) {
                            Text("授業別出席状況")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            LazyVStack(spacing: 12) {
                                ForEach(getCourseStatistics(), id: \.course.courseId) { stat in
                                    CourseStatisticRow(statistic: stat)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // 週間出席グラフ（仮）
                        VStack(alignment: .leading, spacing: 16) {
                            Text("週間出席状況")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            VStack {
                                // ここでChart APIを使用してグラフを表示
                                Text("グラフエリア")
                                    .frame(maxWidth: .infinity, minHeight: 200)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                        
                        Spacer(minLength: 50)
                    } else {
                        // シートが選択されていない場合の表示
                        VStack(spacing: 20) {
                            Image(systemName: "chart.bar.doc.horizontal")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("統計を表示するシートを選択してください")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    }
                }
            }
            .navigationTitle("統計")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            initializeDefaultSemester()
        }
        .onReceive(NotificationCenter.default.publisher(for: .semesterDataDidChange)) { _ in
            // 学期データが変更された時に統計を再計算
            if let selectedSemester = selectedSemesterForStats {
                loadCoursesForSemester(selectedSemester)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .semesterPeriodDidChange)) { notification in
            // 期間が変更された学期が現在選択中の学期の場合、統計を更新
            if let changedSemester = notification.object as? Semester,
               changedSemester.semesterId == selectedSemesterForStats?.semesterId {
                loadCoursesForSemester(changedSemester)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .courseDataDidChange)) { _ in
            // 授業データが変更された時に統計を再計算
            if let selectedSemester = selectedSemesterForStats {
                loadCoursesForSemester(selectedSemester)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// 統計用シートを選択
    private func selectSemesterForStats(_ semester: Semester) {
        isLoading = true
        selectedSemesterForStats = semester
        loadCoursesForSemester(semester)
    }
    
    /// デフォルトシートを初期化
    private func initializeDefaultSemester() {
        if selectedSemesterForStats == nil && !viewModel.availableSemesters.isEmpty {
            // 時間割タブで選択中のシートがあればそれを、なければ最初のシートを選択
            let defaultSemester = viewModel.currentSemester ?? viewModel.availableSemesters.first
            if let semester = defaultSemester {
                selectSemesterForStats(semester)
            }
        }
    }
    
    /// 指定学期の授業を読み込み
    private func loadCoursesForSemester(_ semester: Semester) {
        let request: NSFetchRequest<Course> = Course.fetchRequest()
        request.predicate = NSPredicate(format: "semester == %@", semester)
        
        do {
            coursesForSelectedSemester = try viewModel.managedObjectContext.fetch(request)
            isLoading = false
        } catch {
            print("授業データの読み込みエラー: \(error)")
            coursesForSelectedSemester = []
            isLoading = false
        }
    }
    
    /// 今週の欠席数を計算（最適化版）
    private func getWeeklyAbsenceCount() -> Int {
        guard !coursesForSelectedSemester.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        let now = Date()
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        
        let courseIds = coursesForSelectedSemester.map { $0.objectID }
        
        let request: NSFetchRequest<AttendanceRecord> = AttendanceRecord.fetchRequest()
        request.predicate = NSPredicate(
            format: "course IN %@ AND date >= %@ AND date <= %@ AND type IN %@",
            courseIds,
            weekInterval.start as NSDate,
            weekInterval.end as NSDate,
            AttendanceType.allCases.filter { $0.affectsCredit }.map { $0.rawValue }
        )
        
        do {
            return try viewModel.managedObjectContext.count(for: request)
        } catch {
            print("週間欠席数計算エラー: \(error)")
            return 0
        }
    }
    
    /// 平均出席率を計算
    private func getAverageAttendanceRate() -> Double {
        guard !coursesForSelectedSemester.isEmpty else { return 0.0 }
        
        var totalRate = 0.0
        for course in coursesForSelectedSemester {
            let absenceCount = viewModel.getCachedAbsenceCount(for: course)
            let maxAbsences = Int(course.maxAbsences)
            let attendanceRate = maxAbsences > 0 ? Double(max(0, maxAbsences - absenceCount)) / Double(maxAbsences) : 1.0
            totalRate += attendanceRate
        }
        
        return (totalRate / Double(coursesForSelectedSemester.count)) * 100
    }
    
    /// 注意が必要な科目数を計算
    private func getWarningCoursesCount() -> Int {
        var warningCount = 0
        for course in coursesForSelectedSemester {
            let remainingAbsences = viewModel.getRemainingAbsences(for: course)
            if remainingAbsences <= 2 {
                warningCount += 1
            }
        }
        return warningCount
    }
    
    private func getCourseStatistics() -> [CourseStatistic] {
        return coursesForSelectedSemester.map { course in
            let absenceCount = viewModel.getCachedAbsenceCount(for: course)
            let maxAbsences = Int(course.maxAbsences)
            let attendedClasses = max(0, maxAbsences - absenceCount)
            let attendanceRate = maxAbsences > 0 ? Double(attendedClasses) / Double(maxAbsences) : 1.0
            
            return CourseStatistic(
                course: course,
                totalClasses: maxAbsences,
                attendedClasses: attendedClasses,
                absences: absenceCount,
                attendanceRate: attendanceRate
            )
        }
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(color)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(cornerRadius: 12, shadowRadius: 2)
    }
}

struct CourseStatistic {
    let course: Course
    let totalClasses: Int
    let attendedClasses: Int
    let absences: Int
    let attendanceRate: Double
}

struct CourseStatisticRow: View {
    let statistic: CourseStatistic
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(statistic.course.courseName ?? "")
                    .font(.system(size: 16, weight: .medium))
                
                Spacer()
                
                Text("\(Int(statistic.attendanceRate * 100))%")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(attendanceRateColor)
            }
            
            HStack(spacing: 20) {
                StatItem(title: "出席", value: "\(statistic.attendedClasses)", color: .green)
                StatItem(title: "欠席", value: "\(statistic.absences)", color: .red)
                StatItem(title: "総回数", value: "\(statistic.totalClasses)", color: .blue)
            }
            
            // 出席率バー
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(attendanceRateColor)
                        .frame(width: geometry.size.width * CGFloat(statistic.attendanceRate), height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .cardStyle(cornerRadius: 12, shadowRadius: 1)
    }
    
    private var attendanceRateColor: Color {
        if statistic.attendanceRate >= 0.8 {
            return .green
        } else if statistic.attendanceRate >= 0.6 {
            return .orange
        } else {
            return .red
        }
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    StatisticsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AttendanceViewModel(persistenceController: .preview))
}