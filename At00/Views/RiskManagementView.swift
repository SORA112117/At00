//
//  RiskManagementView.swift
//  At00
//
//  単位危険度管理画面
//

import SwiftUI
import CoreData

struct RiskManagementView: View {
    @StateObject private var viewModel = AttendanceViewModel()
    
    // 危険度別の科目を取得
    private var criticalCourses: [Course] {
        allCourses.filter { course in
            getAbsenceCount(for: course) >= Int(course.maxAbsences)
        }
    }
    
    private var warningCourses: [Course] {
        allCourses.filter { course in
            let absenceCount = getAbsenceCount(for: course)
            let threshold = max(1, (Int(course.maxAbsences) * 2) / 3)
            return absenceCount >= threshold && absenceCount < Int(course.maxAbsences)
        }
    }
    
    private var safeCourses: [Course] {
        allCourses.filter { course in
            let absenceCount = getAbsenceCount(for: course)
            let threshold = max(1, (Int(course.maxAbsences) * 2) / 3)
            return absenceCount < threshold
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
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if allCourses.isEmpty {
                        emptyStateView
                    } else {
                        overallRiskCard
                        
                        if !criticalCourses.isEmpty {
                            riskSection(
                                title: "危険",
                                courses: criticalCourses,
                                color: .red,
                                icon: "exclamationmark.triangle.fill"
                            )
                        }
                        
                        if !warningCourses.isEmpty {
                            riskSection(
                                title: "注意",
                                courses: warningCourses,
                                color: .orange,
                                icon: "exclamationmark.circle.fill"
                            )
                        }
                        
                        if !safeCourses.isEmpty {
                            riskSection(
                                title: "安全",
                                courses: safeCourses,
                                color: .green,
                                icon: "checkmark.circle.fill"
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("単位危険度")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // 全体状況サマリーカード
    private var overallRiskCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text(viewModel.currentSemesterType.displayName)
                    .font(.headline)
                Spacer()
                Text("危険度サマリー")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 30) {
                summaryItem(
                    count: criticalCourses.count,
                    label: "危険",
                    color: .red,
                    icon: "exclamationmark.triangle.fill"
                )
                
                summaryItem(
                    count: warningCourses.count,
                    label: "注意",
                    color: .orange,
                    icon: "exclamationmark.circle.fill"
                )
                
                summaryItem(
                    count: safeCourses.count,
                    label: "安全",
                    color: .green,
                    icon: "checkmark.circle.fill"
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    private func summaryItem(count: Int, label: String, color: Color, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text("\(count)")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // 危険度セクション
    private func riskSection(title: String, courses: [Course], color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text("\(title) (\(courses.count)科目)")
                    .font(.headline)
                    .foregroundColor(color)
            }
            
            ForEach(courses, id: \.courseId) { course in
                courseRiskCard(course: course, riskColor: color)
            }
        }
    }
    
    // 科目詳細カード
    private func courseRiskCard(course: Course, riskColor: Color) -> some View {
        HStack(spacing: 12) {
            // カラーライン
            RoundedRectangle(cornerRadius: 2)
                .fill(DesignSystem.getColor(for: Int(course.colorIndex)))
                .frame(width: 4, height: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(course.courseName ?? "")
                        .font(.headline)
                    
                    Spacer()
                    
                    if course.isFullYear {
                        Text("通年")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.1))
                            .foregroundColor(.purple)
                            .clipShape(Capsule())
                    }
                }
                
                HStack {
                    let absenceCount = getAbsenceCount(for: course)
                    let maxAbsences = Int(course.maxAbsences)
                    
                    Text("欠席: \(absenceCount)/\(maxAbsences)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if absenceCount >= maxAbsences {
                        Text("上限超過")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(riskColor)
                            .clipShape(Capsule())
                    } else {
                        let remaining = maxAbsences - absenceCount
                        Text("残り\(remaining)回")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(riskColor)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(riskColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    // 空状態表示
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("授業が登録されていません")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("時間割画面から授業を追加してください")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(40)
    }
    
    // 欠席回数を取得
    private func getAbsenceCount(for course: Course) -> Int {
        viewModel.getAbsenceCount(for: course)
    }
}

#Preview {
    RiskManagementView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}