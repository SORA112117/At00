//
//  EnhancedStatisticsView.swift
//  At00
//
//  強化された統計表示画面（棒グラフ対応）
//

import SwiftUI
import CoreData

struct EnhancedStatisticsView: View {
    @StateObject private var viewModel = AttendanceViewModel()
    @State private var selectedTimeFrame: TimeFrame = .weekly
    @State private var selectedPeriod = Date()
    
    enum TimeFrame: String, CaseIterable {
        case weekly = "週"
        case monthly = "月"
        
        var displayName: String { rawValue }
    }
    
    // 現在の期間の日付範囲を取得
    private var currentPeriodDates: (start: Date, end: Date) {
        let calendar = Calendar.current
        
        switch selectedTimeFrame {
        case .weekly:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedPeriod)?.start ?? selectedPeriod
            let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? selectedPeriod
            return (startOfWeek, endOfWeek)
        case .monthly:
            let startOfMonth = calendar.dateInterval(of: .month, for: selectedPeriod)?.start ?? selectedPeriod
            let endOfMonth = calendar.dateInterval(of: .month, for: selectedPeriod)?.end ?? selectedPeriod
            return (startOfMonth, endOfMonth)
        }
    }
    
    // 期間の表示テキスト
    private var periodDisplayText: String {
        let formatter = DateFormatter()
        let (start, end) = currentPeriodDates
        
        switch selectedTimeFrame {
        case .weekly:
            formatter.dateFormat = "M/d"
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        case .monthly:
            formatter.dateFormat = "yyyy年M月"
            return formatter.string(from: selectedPeriod)
        }
    }
    
    // すべての科目を取得
    private var allCourses: [Course] {
        guard let semester = viewModel.currentSemester else { return [] }
        
        let request: NSFetchRequest<Course> = Course.fetchRequest()
        request.predicate = NSPredicate(format: "semester == %@", semester)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Course.dayOfWeek, ascending: true),
            NSSortDescriptor(keyPath: \Course.period, ascending: true)
        ]
        
        return (try? viewModel.managedObjectContext.fetch(request)) ?? []
    }
    
    // 期間内の最大欠席数（グラフの高さ正規化用）
    private var maxAbsenceCount: Int {
        allCourses.map { getAbsencesInPeriod(for: $0).count }.max() ?? 1
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 期間選択UI
                    periodSelectorView
                    
                    // 統計サマリー
                    statisticsSummaryView
                    
                    if !allCourses.isEmpty {
                        // 棒グラフセクション
                        barChartSection
                        
                        // 詳細リスト
                        courseDetailsList
                    } else {
                        emptyStateView
                    }
                }
                .padding()
            }
            .navigationTitle("出席統計")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // 期間選択ビュー
    private var periodSelectorView: some View {
        VStack(spacing: 16) {
            // 週・月切り替え
            Picker("期間", selection: $selectedTimeFrame.animation()) {
                ForEach(TimeFrame.allCases, id: \.self) { frame in
                    Text(frame.displayName).tag(frame)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // 期間ナビゲーション
            HStack {
                Button(action: previousPeriod) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text(periodDisplayText)
                        .font(.headline)
                    Text(viewModel.currentSemesterType.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: nextPeriod) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // 統計サマリー
    private var statisticsSummaryView: some View {
        HStack(spacing: 20) {
            statisticItem(
                title: "総科目数",
                value: "\(allCourses.count)",
                color: .blue,
                icon: "book.fill"
            )
            
            statisticItem(
                title: "期間内欠席",
                value: "\(totalAbsencesInPeriod)",
                color: .orange,
                icon: "calendar.badge.minus"
            )
            
            statisticItem(
                title: "累計欠席",
                value: "\(totalAbsencesAllTime)",
                color: .red,
                icon: "exclamationmark.circle.fill"
            )
        }
    }
    
    private func statisticItem(title: String, value: String, color: Color, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // 棒グラフセクション
    private var barChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("科目別欠席数")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 16) {
                    ForEach(allCourses, id: \.courseId) { course in
                        barChart(for: course)
                    }
                }
                .padding(.vertical)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    // 個別の棒グラフ
    private func barChart(for course: Course) -> some View {
        let absencesInPeriod = getAbsencesInPeriod(for: course).count
        let barHeight = maxAbsenceCount > 0 ? 
            (Double(absencesInPeriod) / Double(maxAbsenceCount)) * 150 : 0
        
        return VStack(spacing: 8) {
            // 数値表示
            Text("\(absencesInPeriod)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.getColor(for: Int(course.colorIndex)))
            
            // 棒グラフ
            RoundedRectangle(cornerRadius: 4)
                .fill(DesignSystem.getColor(for: Int(course.colorIndex)))
                .frame(width: 30, height: max(CGFloat(barHeight), 4))
                .animation(.easeInOut(duration: 0.3), value: barHeight)
            
            // 科目名
            Text(course.courseName ?? "")
                .font(.caption2)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 60)
        }
    }
    
    // 詳細リスト
    private var courseDetailsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("詳細")
                .font(.headline)
            
            ForEach(allCourses, id: \.courseId) { course in
                courseDetailRow(course: course)
            }
        }
    }
    
    private func courseDetailRow(course: Course) -> some View {
        HStack(spacing: 12) {
            // カラーライン
            RoundedRectangle(cornerRadius: 2)
                .fill(DesignSystem.getColor(for: Int(course.colorIndex)))
                .frame(width: 4, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(course.courseName ?? "")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("\(getAbsencesInPeriod(for: course).count)回")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.getColor(for: Int(course.colorIndex)))
                }
                
                HStack {
                    Text("累計: \(viewModel.getAbsenceCount(for: course))/\(course.maxAbsences)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if course.isFullYear {
                        Text("通年")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.1))
                            .foregroundColor(.purple)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
    
    // 空状態表示
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("データがありません")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("授業を登録して出席を記録してください")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(40)
    }
    
    // MARK: - Helper Methods
    
    private func previousPeriod() {
        withAnimation {
            switch selectedTimeFrame {
            case .weekly:
                selectedPeriod = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: selectedPeriod) ?? selectedPeriod
            case .monthly:
                selectedPeriod = Calendar.current.date(byAdding: .month, value: -1, to: selectedPeriod) ?? selectedPeriod
            }
        }
    }
    
    private func nextPeriod() {
        withAnimation {
            switch selectedTimeFrame {
            case .weekly:
                selectedPeriod = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: selectedPeriod) ?? selectedPeriod
            case .monthly:
                selectedPeriod = Calendar.current.date(byAdding: .month, value: 1, to: selectedPeriod) ?? selectedPeriod
            }
        }
    }
    
    private func getAbsencesInPeriod(for course: Course) -> [AttendanceRecord] {
        let (startDate, endDate) = currentPeriodDates
        
        guard let records = course.attendanceRecords as? Set<AttendanceRecord> else { return [] }
        
        return records.filter { record in
            guard let date = record.date else { return false }
            return date >= startDate && date <= endDate && 
                   AttendanceType(rawValue: record.type ?? "")?.affectsCredit == true
        }
    }
    
    private var totalAbsencesInPeriod: Int {
        allCourses.reduce(0) { $0 + getAbsencesInPeriod(for: $1).count }
    }
    
    private var totalAbsencesAllTime: Int {
        allCourses.reduce(0) { $0 + viewModel.getAbsenceCount(for: $1) }
    }
}

// Array安全アクセス用の拡張
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    EnhancedStatisticsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}