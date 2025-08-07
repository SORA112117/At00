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
                    // 統一されたローディング表示
                    DesignSystem.LoadingView(message: "読み込み中...")
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
                    .secondaryButtonStyle()
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedTab == .new {
                        Button("保存") {
                            saveNewCourse()
                        }
                        .primaryButtonStyle(isDisabled: newCourseName.isEmpty)
                    } else {
                        Button("保存") {
                            if let course = selectedExistingCourse {
                                saveExistingCourse(course)
                            }
                        }
                        .primaryButtonStyle(isDisabled: selectedExistingCourse == nil)
                    }
                }
            }
            .onAppear {
                // 初期化状態のチェック
                print("CourseSelectionView onAppear - isInitialized: \(viewModel.isInitialized), currentSemester: \(viewModel.currentSemester?.name ?? "nil")")
                
                // ViewModelが初期化されていない場合はエラー表示
                if !viewModel.isInitialized {
                    print("ViewModelが未初期化です。初期化の完了を待っています...")
                    // 初期化エラーがある場合は再試行を促す
                    if viewModel.initializationError != nil {
                        viewModel.retryInitialization()
                    }
                    return
                }
                
                // currentSemesterが存在することを確認
                guard viewModel.currentSemester != nil else {
                    print("エラー: currentSemesterがnilです")
                    viewModel.errorBanner = ErrorBannerInfo(
                        message: "学期情報の読み込みに失敗しました",
                        type: .dataNotFound
                    )
                    return
                }
                
                // 既存授業を読み込み
                loadAvailableExistingCourses()
                
                // 表示フラグを設定
                if !hasAppeared {
                    hasAppeared = true
                }
            }
            .background(Color(.systemGroupedBackground)) // 背景色を明示的に設定
            .animation(hasAppeared ? .easeInOut(duration: 0.3) : nil, value: selectedTab)
            .alert("授業の登録エラー", isPresented: $showingDuplicateAlert) {
                Button("OK") { }
            } message: {
                Text(duplicateAlertMessage)
            }
            .alert("授業名の重複エラー", isPresented: $showingNewCourseDuplicateAlert) {
                Button("OK") { }
            } message: {
                Text(newCourseDuplicateMessage)
            }
        }
    
    private func loadAvailableExistingCourses() {
        guard let semester = viewModel.currentSemester else { return }
        
        // 1. 現在の学期の授業を取得
        let currentSemesterRequest: NSFetchRequest<Course> = Course.fetchRequest()
        currentSemesterRequest.predicate = NSPredicate(format: "semester == %@", semester)
        
        let currentSemesterCourses = (try? viewModel.managedObjectContext.fetch(currentSemesterRequest)) ?? []
        
        // 2. 現在の位置に既に配置されていない授業のみを表示
        availableExistingCourses = currentSemesterCourses.compactMap { course in
            guard let courseName = course.courseName,
                  !courseName.isEmpty,
                  !(course.dayOfWeek == dayOfWeek && course.period == period) else {
                return nil
            }
            
            return course
        }
        
        // 3. 授業名でソート
        availableExistingCourses.sort { course1, course2 in
            let name1 = course1.courseName ?? ""
            let name2 = course2.courseName ?? ""
            return name1 < name2
        }
    }
    
    @State private var showingNewCourseDuplicateAlert = false
    @State private var newCourseDuplicateMessage = ""
    
    private func saveNewCourse() {
        // 全学期を通じた同名科目のチェック
        if viewModel.hasCourseWithSameNameAcrossAllSemesters(newCourseName) {
            // 現在の学期にあるか、他の学期にあるかで異なるメッセージを表示
            if viewModel.hasCourseWithSameName(newCourseName) {
                newCourseDuplicateMessage = "「\(newCourseName)」という名前の授業は、この時間割シートに既に登録されています。\n\n異なる授業名を使用してください。"
            } else {
                newCourseDuplicateMessage = "「\(newCourseName)」という名前の授業は、別の時間割シートに既に登録されています。\n\n同じ授業名を複数のシートで使用することはできません。異なる授業名を使用してください。"
            }
            showingNewCourseDuplicateAlert = true
            return
        }
        
        let newCourse = viewModel.addCourse(
            name: newCourseName,
            dayOfWeek: dayOfWeek,
            period: period,
            totalClasses: newTotalClasses,
            maxAbsences: newMaxAbsences,
            colorIndex: newSelectedColorIndex
        )
        
        switch newCourse {
        case .success:
            print("新規授業作成成功: \(newCourseName)")
        case .currentSlotOccupied:
            print("新規授業作成失敗（現在のスロット占有）: \(newCourseName)")
        }
        
        // 即座に時間割を再読み込み
        viewModel.loadTimetable()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            dismiss()
        }
    }
    
    @State private var showingDuplicateAlert = false
    @State private var duplicateAlertMessage = ""
    
    private func saveExistingCourse(_ course: Course) {
        // 既存の授業を新しい時間割に配置（複製）
        let result = viewModel.assignExistingCourse(
            course: course,
            newDayOfWeek: dayOfWeek,
            newPeriod: period
        )
        
        switch result {
        case .success:
            // 即座に時間割を再読み込み
            viewModel.loadTimetable()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                dismiss()
            }
        case .slotOccupied:
            duplicateAlertMessage = "この時間帯には既に授業が登録されています。"
            showingDuplicateAlert = true
        case .duplicateNameInSemester:
            duplicateAlertMessage = "「\(course.courseName ?? "")」という名前の授業は、この時間割シートの別の時限に既に登録されています。\n\n同じ授業を複数の時限に登録することはできません。"
            showingDuplicateAlert = true
        case .duplicateNameAcrossSemesters:
            duplicateAlertMessage = "「\(course.courseName ?? "")」という名前の授業は、別の時間割シートに既に登録されています。\n\n同じ授業名を複数のシートで使用することはできません。"
            showingDuplicateAlert = true
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
                // 統一された空状態表示
                DesignSystem.EmptyStateView(
                    icon: "book.closed",
                    title: "既存授業がありません",
                    message: "新規作成から授業を追加してください"
                )
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
                        
                        // 学期情報を表示
                        Text(course.semester?.name ?? "不明")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color(.systemGray5))
                            .foregroundColor(.secondary)
                            .clipShape(Capsule())
                        
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
                        .keyboardType(.default)
                        .disableAutocorrection(true)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: DesignSystem.adaptiveShadowColor, radius: 4, x: 0, y: 2)
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
                        
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: DesignSystem.adaptiveShadowColor, radius: 4, x: 0, y: 2)
                )
                .onChange(of: totalClasses) { _, newValue in
                    maxAbsences = max(1, newValue / 3)
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
                        .shadow(color: DesignSystem.adaptiveShadowColor, radius: 4, x: 0, y: 2)
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