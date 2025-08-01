//
//  StatisticsView.swift
//  At00
//
//  統計表示画面
//

import SwiftUI
import Charts

struct StatisticsView: View {
    @StateObject private var viewModel = AttendanceViewModel()
    @State private var selectedPeriod: StatisticsPeriod = .thisWeek
    
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
                                value: "12",
                                subtitle: "科目",
                                color: .blue,
                                icon: "book.fill"
                            )
                            
                            SummaryCard(
                                title: "今週の欠席",
                                value: "2",
                                subtitle: "回",
                                color: .red,
                                icon: "exclamationmark.triangle.fill"
                            )
                            
                            SummaryCard(
                                title: "出席率",
                                value: "92%",
                                subtitle: "平均",
                                color: .green,
                                icon: "chart.line.uptrend.xyaxis"
                            )
                            
                            SummaryCard(
                                title: "注意科目",
                                value: "1",
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
                }
            }
            .navigationTitle("統計")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private func getCourseStatistics() -> [CourseStatistic] {
        // 実際の実装では、ViewModelから統計データを取得
        return [
            CourseStatistic(
                course: createSampleCourse("プログラミング基礎"),
                totalClasses: 15,
                attendedClasses: 13,
                absences: 2,
                attendanceRate: 0.87
            ),
            CourseStatistic(
                course: createSampleCourse("データ構造"),
                totalClasses: 15,
                attendedClasses: 14,
                absences: 1,
                attendanceRate: 0.93
            )
        ]
    }
    
    private func createSampleCourse(_ name: String) -> Course {
        let course = Course(context: PersistenceController.preview.container.viewContext)
        course.courseName = name
        course.courseId = UUID()
        return course
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
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(attendanceRateColor)
                        .frame(width: geometry.size.width * statistic.attendanceRate, height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
        }
        .padding()
        .cardStyle(cornerRadius: 12, shadowRadius: 2)
    }
    
    private var attendanceRateColor: Color {
        if statistic.attendanceRate >= 0.9 {
            return .green
        } else if statistic.attendanceRate >= 0.7 {
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
}