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
    
    @State private var selectedTab: CourseSelectionTab = .new
    @State private var availableExistingCourses: [Course] = []
    @State private var selectedExistingCourse: Course?
    @State private var hasAppeared = false // 初回表示フラグ追加
    
    // 新規作成用のState
    @State private var newCourseName = ""
    @State private var newTotalClasses = 15
    @State private var newMaxAbsences = 5
    @State private var newIsFullYear = false
    @State private var newSelectedColorIndex = 0
    
    enum CourseSelectionTab: String, CaseIterable {
        case new = "新規作成"
        case existing = "既存授業"
        
        var displayName: String { rawValue }
    }
    
    private let dayNames = ["", "月", "火", "水", "木", "金", "土", "日"]
    
    private var canSave: Bool {
        if selectedTab == .new {
            return !newCourseName.isEmpty
        } else {
            return selectedExistingCourse != nil
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
                // タブ選択
                Picker("選択方法", selection: $selectedTab) {
                    ForEach(CourseSelectionTab.allCases, id: \.self) { tab in
                        Text(tab.displayName).tag(tab)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // ViewModelが初期化されているか確認
                if !viewModel.isInitialized || viewModel.currentSemester == nil {
                    // 初期化中の表示
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding()
                        Text("読み込み中...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else {
                    // コンテンツ
                    ZStack {
                        // 背景色を常に表示
                        Color(.systemGroupedBackground)
                            .ignoresSafeArea()
                        
                        if selectedTab == .new {
                        NewCourseCreationView(
                            dayOfWeek: dayOfWeek,
                            period: period,
                            viewModel: viewModel,
                            courseName: $newCourseName,
                            totalClasses: $newTotalClasses,
                            maxAbsences: $newMaxAbsences,
                            isFullYear: $newIsFullYear,
                            selectedColorIndex: $newSelectedColorIndex
                        )
                        .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))
                    } else {
                        ExistingCourseSelectionView(
                            dayOfWeek: dayOfWeek,
                            period: period,
                            viewModel: viewModel,
                            availableCourses: availableExistingCourses,
                            selectedCourse: $selectedExistingCourse
                        )
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                    }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("授業選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedTab == .new {
                        Button("保存") {
                            saveNewCourse()
                        }
                        .disabled(newCourseName.isEmpty)
                        .fontWeight(.semibold)
                    } else {
                        Button("保存") {
                            if let course = selectedExistingCourse {
                                saveExistingCourse(course)
                            }
                        }
                        .disabled(selectedExistingCourse == nil)
                        .fontWeight(.semibold)
                    }
                }
            }
            .onAppear {
                // ViewModelの初期化を確実に待つ
                if viewModel.currentSemester == nil {
                    // currentSemesterがない場合は再読み込み
                    viewModel.loadCurrentSemester()
                }
                
                // 少し遅延を入れて確実に初期化
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    loadAvailableExistingCourses()
                    if !hasAppeared {
                        hasAppeared = true
                    }
                }
            }
            .background(Color(.systemGroupedBackground)) // 背景色を明示的に設定
            .animation(hasAppeared ? .easeInOut(duration: 0.3) : nil, value: selectedTab)
        }
    
    private func loadAvailableExistingCourses() {
        guard let semester = viewModel.currentSemester else { return }
        
        let request: NSFetchRequest<Course> = Course.fetchRequest()
        request.predicate = NSPredicate(format: "semester == %@", semester)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Course.courseName, ascending: true)
        ]
        
        let allCourses = (try? viewModel.managedObjectContext.fetch(request)) ?? []
        
        // 重複した名前の授業を除外し、現在の位置に既に配置されていない授業のみを表示
        var uniqueCourseNames = Set<String>()
        availableExistingCourses = allCourses.compactMap { course in
            guard let courseName = course.courseName,
                  !courseName.isEmpty,
                  !(course.dayOfWeek == dayOfWeek && course.period == period) else {
                return nil
            }
            
            // 既に同名の授業が存在する場合はスキップ
            if uniqueCourseNames.contains(courseName) {
                return nil
            }
            
            uniqueCourseNames.insert(courseName)
            return course
        }
    }
    
    private func saveNewCourse() {
        // 同名の授業が既に存在しないかチェック
        guard !courseNameExists(newCourseName) else {
            // 同名の授業が存在する場合はアラートを表示するなどの処理を追加可能
            return
        }
        
        viewModel.addCourse(
            name: newCourseName,
            dayOfWeek: dayOfWeek,
            period: period,
            totalClasses: newTotalClasses,
            isFullYear: newIsFullYear,
            colorIndex: newSelectedColorIndex
        )
        
        // 即座に時間割を再読み込み
        viewModel.loadTimetable()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            dismiss()
        }
    }
    
    private func saveExistingCourse(_ course: Course) {
        // 既存の授業を新しい時間割に配置（複製）
        viewModel.assignExistingCourse(
            course: course,
            newDayOfWeek: dayOfWeek,
            newPeriod: period
        )
        
        // 即座に時間割を再読み込み
        viewModel.loadTimetable()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            dismiss()
        }
    }
    
    private func courseNameExists(_ name: String) -> Bool {
        guard let semester = viewModel.currentSemester else { return false }
        
        let request: NSFetchRequest<Course> = Course.fetchRequest()
        request.predicate = NSPredicate(format: "semester == %@ AND courseName == %@", semester, name)
        request.fetchLimit = 1
        
        return (try? viewModel.managedObjectContext.fetch(request).first) != nil
    }
}

// MARK: - 既存授業選択ビュー
struct ExistingCourseSelectionView: View {
    let dayOfWeek: Int
    let period: Int
    @ObservedObject var viewModel: AttendanceViewModel
    let availableCourses: [Course]
    @Binding var selectedCourse: Course?
    @Environment(\.dismiss) private var dismiss
    
    private let dayNames = ["", "月", "火", "水", "木", "金", "土", "日"]
    
    var body: some View {
        Group {
            if availableCourses.isEmpty {
                // 既存授業がない場合の表示
                VStack(spacing: 20) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 50))
                        .foregroundColor(.gray.opacity(0.6))
                    
                    Text("既存授業がありません")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("新規作成から授業を追加してください")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            } else {
                // 既存授業のシンプルなリスト
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(availableCourses, id: \.courseId) { course in
                            let isSelected = selectedCourse?.courseId == course.courseId
                            SimpleExistingCourseCard(
                                course: course,
                                isSelected: isSelected,
                                viewModel: viewModel,
                                onSelection: {
                                    selectedCourse = course
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .background(Color(.systemGroupedBackground))
            }
        }
    }
}

// MARK: - シンプルな既存授業カード
struct SimpleExistingCourseCard: View {
    let course: Course
    let isSelected: Bool
    @ObservedObject var viewModel: AttendanceViewModel
    let onSelection: () -> Void
    
    var body: some View {
        ZStack {
            // 背景とボーダー
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.blue.opacity(0.15) : Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.blue : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
                )
                .scaleEffect(isSelected ? 1.02 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isSelected)
            
            // カード内容
            HStack(spacing: 12) {
                // カラーライン
                Rectangle()
                    .fill(DesignSystem.getColor(for: Int(course.colorIndex)))
                    .frame(width: 4)
                    .cornerRadius(2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(course.courseName ?? "")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text("欠席: \(viewModel.getAbsenceCount(for: course))回")
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
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .contentShape(Rectangle()) // 確実にカード全体をタップ可能にする
        .onTapGesture {
            onSelection()
        }
    }
    
}

// MARK: - 新規作成ビュー
struct NewCourseCreationView: View {
    let dayOfWeek: Int
    let period: Int
    @ObservedObject var viewModel: AttendanceViewModel
    
    @Binding var courseName: String
    @Binding var totalClasses: Int
    @Binding var maxAbsences: Int
    @Binding var isFullYear: Bool
    @Binding var selectedColorIndex: Int
    
    private let dayNames = ["", "月", "火", "水", "木", "金", "土", "日"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 授業情報
                VStack(alignment: .leading, spacing: 16) {
                    Text("授業情報")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    TextField("授業名を入力", text: $courseName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.body)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .onTapGesture {
                            // TextFieldを確実にアクティブにする
                        }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                )
                
                // 授業設定
                VStack(alignment: .leading, spacing: 16) {
                    Text("授業設定")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(spacing: 12) {
                        HStack {
                            Text("総授業回数")
                            Spacer()
                            Stepper("\(totalClasses)回", value: $totalClasses, in: 1...30)
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("最大欠席可能")
                            Spacer()
                            Stepper("\(maxAbsences)回", value: $maxAbsences, in: 1...15)
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("通年科目")
                            Spacer()
                            Toggle("", isOn: $isFullYear)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                )
                .onChange(of: totalClasses) { _, newValue in
                    maxAbsences = max(1, newValue / 3)
                }
                .onChange(of: isFullYear) { _, newValue in
                    if newValue {
                        totalClasses = 30
                        maxAbsences = 10
                    } else {
                        totalClasses = 15
                        maxAbsences = 5
                    }
                }
                
                // カラー選択
                VStack(alignment: .leading, spacing: 16) {
                    Text("カラー")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                        ForEach(0..<8, id: \.self) { index in
                            Circle()
                                .fill(DesignSystem.getColor(for: index))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: selectedColorIndex == index ? 3 : 0)
                                )
                                .onTapGesture {
                                    withAnimation(.spring()) {
                                        selectedColorIndex = index
                                    }
                                }
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                )
                
                // ヒント
                Text("※ 欠席可能回数は総授業回数の1/3が目安です")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            .padding()
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