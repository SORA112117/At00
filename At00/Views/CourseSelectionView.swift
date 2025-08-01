//
//  CourseSelectionView.swift
//  At00
//
//  授業選択画面（新規作成か既存選択か）
//

import SwiftUI
import CoreData

struct CourseSelectionView: View {
    let dayOfWeek: Int
    let period: Int
    @ObservedObject var viewModel: AttendanceViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: CourseSelectionTab = .existing
    @State private var availableExistingCourses: [Course] = []
    
    enum CourseSelectionTab: String, CaseIterable {
        case existing = "既存授業"
        case new = "新規作成"
        
        var displayName: String { rawValue }
    }
    
    private let dayNames = ["", "月", "火", "水", "木", "金", "土", "日"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // タブ選択
                Picker("選択方法", selection: $selectedTab) {
                    ForEach(CourseSelectionTab.allCases, id: \.self) { tab in
                        Text(tab.displayName).tag(tab)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // コンテンツ
                TabView(selection: $selectedTab) {
                    // 既存授業選択タブ
                    ExistingCourseSelectionView(
                        dayOfWeek: dayOfWeek,
                        period: period,
                        viewModel: viewModel,
                        availableCourses: availableExistingCourses
                    )
                    .tag(CourseSelectionTab.existing)
                    
                    // 新規作成タブ
                    NewCourseCreationView(
                        dayOfWeek: dayOfWeek,
                        period: period,
                        viewModel: viewModel
                    )
                    .tag(CourseSelectionTab.new)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("授業選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadAvailableExistingCourses()
            }
        }
    }
    
    private func loadAvailableExistingCourses() {
        guard let semester = viewModel.currentSemester else { return }
        
        let request: NSFetchRequest<Course> = Course.fetchRequest()
        request.predicate = NSPredicate(format: "semester == %@", semester)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Course.courseName, ascending: true)
        ]
        
        let allCourses = (try? viewModel.managedObjectContext.fetch(request)) ?? []
        
        // 現在の位置に既に配置されていない授業のみを表示
        availableExistingCourses = allCourses.filter { course in
            !(course.dayOfWeek == dayOfWeek && course.period == period)
        }
    }
}

// MARK: - 既存授業選択ビュー
struct ExistingCourseSelectionView: View {
    let dayOfWeek: Int
    let period: Int
    @ObservedObject var viewModel: AttendanceViewModel
    let availableCourses: [Course]
    @Environment(\.dismiss) private var dismiss
    
    private let dayNames = ["", "月", "火", "水", "木", "金", "土", "日"]
    
    var body: some View {
        Group {
            if availableCourses.isEmpty {
                // 既存授業がない場合の表示
                VStack(spacing: 16) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 60))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("利用可能な既存授業がありません")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("新規作成タブから新しい授業を作成してください")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(40)
            } else {
                // 既存授業のリスト
                ScrollView {
                    LazyVStack(spacing: 12) {
                        Section {
                            Text("既存の授業から選択して\n\(dayNames[dayOfWeek])曜日 \(period)限に配置できます")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 8)
                        }
                        
                        ForEach(availableCourses, id: \.courseId) { course in
                            ExistingCourseCard(
                                course: course,
                                dayOfWeek: dayOfWeek,
                                period: period,
                                viewModel: viewModel,
                                onSelection: {
                                    dismiss()
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

// MARK: - 既存授業カード
struct ExistingCourseCard: View {
    let course: Course
    let dayOfWeek: Int
    let period: Int
    @ObservedObject var viewModel: AttendanceViewModel
    let onSelection: () -> Void
    
    private let dayNames = ["", "月", "火", "水", "木", "金", "土", "日"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // カラーライン
                RoundedRectangle(cornerRadius: 2)
                    .fill(DesignSystem.getColor(for: Int(course.colorIndex)))
                    .frame(width: 4, height: 50)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(course.courseName ?? "")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 16) {
                        Text("現在: \(dayNames[Int(course.dayOfWeek)])曜日 \(course.period)限")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
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
                    
                    HStack {
                        Text("欠席: \(viewModel.getAbsenceCount(for: course))/\(course.maxAbsences)")
                            .font(.caption)
                            .foregroundColor(.red)
                        
                        Spacer()
                        
                        Circle()
                            .fill(viewModel.getStatusColor(for: course))
                            .frame(width: 8, height: 8)
                    }
                }
                
                Spacer()
                
                // 選択ボタン
                Button("選択") {
                    assignExistingCourse()
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignSystem.getColor(for: Int(course.colorIndex)))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func assignExistingCourse() {
        // 既存の授業を新しい時間割に配置（複製）
        viewModel.assignExistingCourse(
            course: course,
            newDayOfWeek: dayOfWeek,
            newPeriod: period
        )
        onSelection()
    }
}

// MARK: - 新規作成ビュー
struct NewCourseCreationView: View {
    let dayOfWeek: Int
    let period: Int
    @ObservedObject var viewModel: AttendanceViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var courseName = ""
    @State private var totalClasses = 15
    @State private var maxAbsences = 5
    @State private var isFullYear = false
    @State private var selectedColorIndex = 0
    
    private let dayNames = ["", "月", "火", "水", "木", "金", "土", "日"]
    
    var body: some View {
        Form {
            Section("授業情報") {
                TextField("授業名", text: $courseName)
                
                HStack {
                    Text("曜日・時限")
                    Spacer()
                    Text("\(dayNames[dayOfWeek])曜日 \(period)限")
                        .foregroundColor(.secondary)
                }
            }
            
            Section("授業設定") {
                Stepper("総授業回数: \(totalClasses)回", value: $totalClasses, in: 1...30)
                
                Stepper("最大欠席可能: \(maxAbsences)回", value: $maxAbsences, in: 1...15)
                    .onChange(of: totalClasses) { _, newValue in
                        maxAbsences = max(1, newValue / 3)
                    }
                
                Toggle("通年科目", isOn: $isFullYear)
                    .onChange(of: isFullYear) { _, newValue in
                        if newValue {
                            totalClasses = 30
                            maxAbsences = 10
                        } else {
                            totalClasses = 15
                            maxAbsences = 5
                        }
                    }
                
                HStack {
                    Text("カラー")
                    Spacer()
                    ForEach(0..<8, id: \.self) { index in
                        Circle()
                            .fill(DesignSystem.getColor(for: index))
                            .frame(width: 30, height: 30)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary, lineWidth: selectedColorIndex == index ? 3 : 0)
                            )
                            .onTapGesture {
                                selectedColorIndex = index
                            }
                    }
                }
            }
            
            Section {
                Text("※ 欠席可能回数は総授業回数の1/3が目安です")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section {
                Button("作成") {
                    viewModel.addCourse(
                        name: courseName,
                        dayOfWeek: dayOfWeek,
                        period: period,
                        totalClasses: totalClasses,
                        isFullYear: isFullYear,
                        colorIndex: selectedColorIndex
                    )
                    dismiss()
                }
                .disabled(courseName.isEmpty)
                .frame(maxWidth: .infinity)
                .foregroundColor(.white)
                .padding()
                .background(courseName.isEmpty ? Color.gray : Color.blue)
                .cornerRadius(8)
            }
        }
    }
}

#Preview {
    CourseSelectionView(
        dayOfWeek: 1,
        period: 1,
        viewModel: AttendanceViewModel(persistenceController: .preview)
    )
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}