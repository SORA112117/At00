//
//  TimetableView.swift
//  At00
//
//  時間割表示のメイン画面
//

import SwiftUI
import CoreData

struct TimetableView: View {
    @StateObject private var viewModel = AttendanceViewModel()
    @State private var showingCourseDetail = false
    @State private var selectedCourse: Course?
    @State private var showingAddCourse = false
    @State private var selectedTimeSlot: (day: Int, period: Int)?
    @State private var showingErrorAlert = false
    @State private var showingPeriodTimeSettings = false
    @State private var showingCourseEditDetail = false
    @State private var selectedPeriod: Int?
    @State private var showingPeriodEdit = false
    
    private let dayNames = ["月", "火", "水", "木", "金"]
    private let periods = ["1限", "2限", "3限", "4限", "5限"]
    @State private var timeSlots = ["9:00-10:30", "10:40-12:10", "13:00-14:30", "14:40-16:10", "16:20-17:50"]
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    semesterInfoView
                    timetableGridView(geometry: geometry)
                    Spacer()
                }
            }
            .navigationTitle("授業欠席管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        ForEach(SemesterType.allCases, id: \.self) { type in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    viewModel.switchSemester(to: type)
                                }
                            }) {
                                Label(type.displayName, systemImage: type.icon)
                                if viewModel.currentSemesterType == type {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: viewModel.currentSemesterType.icon)
                            Text(viewModel.currentSemesterType.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("設定") {
                        // 設定画面を表示
                    }
                }
            }
            .sheet(isPresented: $showingCourseDetail) {
                if let course = selectedCourse {
                    CourseDetailView(course: course, viewModel: viewModel)
                }
            }
            .sheet(isPresented: $showingAddCourse) {
                if let timeSlot = selectedTimeSlot {
                    CourseSelectionView(
                        dayOfWeek: timeSlot.day,
                        period: timeSlot.period,
                        viewModel: viewModel
                    )
                }
            }
            .alert("エラー", isPresented: $showingErrorAlert) {
                Button("OK") {
                    viewModel.errorMessage = nil
                    showingErrorAlert = false
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .onChange(of: viewModel.errorMessage) { _, newValue in
                showingErrorAlert = newValue != nil
            }
            .sheet(isPresented: $showingPeriodTimeSettings) {
                PeriodTimeSettingsView()
            }
            .onChange(of: showingPeriodTimeSettings) { _, isShowing in
                if !isShowing {
                    // 設定画面が閉じられたときに時間を再読み込み
                    loadTimeSlots()
                }
            }
            .sheet(isPresented: $showingCourseEditDetail) {
                if let course = selectedCourse {
                    EditCourseDetailView(course: course, viewModel: viewModel)
                }
            }
            .sheet(isPresented: $showingPeriodEdit) {
                if let period = selectedPeriod {
                    SinglePeriodEditView(period: period, viewModel: viewModel)
                }
            }
            .onChange(of: showingPeriodEdit) { _, isShowing in
                if !isShowing {
                    // 個別時限編集画面が閉じられたときも時間を再読み込み
                    loadTimeSlots()
                }
            }
        }
        .onAppear {
            loadTimeSlots()
        }
        .onChange(of: viewModel.currentSemester?.semesterId) { _, _ in
            // 学期が変更されたときも時間を再読み込み
            loadTimeSlots()
        }
        .task {
            // タブ切り替え時にも確実に更新
            loadTimeSlots()
        }
    }
    
    @ViewBuilder
    private var semesterInfoView: some View {
        if let semester = viewModel.currentSemester {
            HStack {
                Text(semester.name ?? "")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text("出席管理")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
        }
    }
    
    private func timetableGridView(geometry: GeometryProxy) -> some View {
        let spacing: CGFloat = 1
        let leftColumnWidth: CGFloat = 50
        let padding: CGFloat = 32 // 左右16pxずつ
        let availableWidth = geometry.size.width - leftColumnWidth - padding - (spacing * 4) // spacing between 5 columns
        let cellWidth = availableWidth / 5
        let cellHeight: CGFloat = max(80, min(100, geometry.size.height / 8))
        
        return ScrollView {
            VStack(spacing: 2) {
                timetableHeaderView(cellWidth: cellWidth)
                timetableBodyView(cellWidth: cellWidth, cellHeight: cellHeight)
            }
            .padding(.horizontal, 16)
        }
    }
    
    private func timetableHeaderView(cellWidth: CGFloat) -> some View {
        HStack(spacing: 1) {
            Text("時限")
                .font(.system(size: 10))
                .frame(width: 50, height: 40)
                .background(Color(.secondarySystemBackground))
                .animation(.easeInOut(duration: 0.3), value: Color(.secondarySystemBackground))
            
            ForEach(0..<5, id: \.self) { dayIndex in
                Text(dayNames[dayIndex])
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: cellWidth, height: 40)
                    .background(Color(.secondarySystemBackground))
                    .animation(.easeInOut(duration: 0.3), value: Color(.secondarySystemBackground))
            }
        }
    }
    
    private func timetableBodyView(cellWidth: CGFloat, cellHeight: CGFloat) -> some View {
        ForEach(0..<5, id: \.self) { periodIndex in
            HStack(spacing: 1) {
                periodHeaderView(for: periodIndex, height: cellHeight)
                courseCellsView(for: periodIndex, cellWidth: cellWidth, cellHeight: cellHeight)
            }
        }
    }
    
    private func periodHeaderView(for periodIndex: Int, height: CGFloat) -> some View {
        Button {
            selectedPeriod = periodIndex + 1  // 1-based period number
            showingPeriodEdit = true
        } label: {
            VStack(spacing: 2) {
                Text(periods[periodIndex])
                    .font(.system(size: 12, weight: .medium))
                Text(timeSlots[periodIndex])
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            }
            .frame(width: 50, height: height)
            .background(Color(.systemGray6))
            .foregroundColor(.primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func courseCellsView(for periodIndex: Int, cellWidth: CGFloat, cellHeight: CGFloat) -> some View {
        ForEach(0..<5, id: \.self) { dayIndex in
            let course = viewModel.timetable[periodIndex][dayIndex]
            EnhancedCourseCell(
                course: course,
                absenceCount: course.map { viewModel.getAbsenceCount(for: $0) } ?? 0,
                statusColor: course.map { viewModel.getStatusColor(for: $0) } ?? .gray,
                cellWidth: cellWidth,
                cellHeight: cellHeight,
                onTap: {
                    if let course = course {
                        handleCourseTap(course)
                    } else {
                        selectedTimeSlot = (day: dayIndex + 1, period: periodIndex + 1)
                        showingAddCourse = true
                    }
                },
                onLongPress: {
                    if let course = course {
                        selectedCourse = course
                        showingCourseEditDetail = true
                    }
                }
            )
        }
    }
    
    private func handleCourseTap(_ course: Course) {
        // ワンタップで欠席記録
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            viewModel.recordAbsence(for: course)
            // 即座にUIを更新
            viewModel.objectWillChange.send()
        }
        
        // 視覚的フィードバック（パーティクルエフェクトのようなアニメーション）
        showFeedbackAnimation(for: course)
        
        // スマートなハプティックフィードバック（欠席記録後の新しい状態で判定）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let remainingAbsences = viewModel.getRemainingAbsences(for: course)
            
            if remainingAbsences <= 0 {
                // 危険な状況：強いバイブレーション
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.error)
            } else if remainingAbsences <= 2 {
                // 警告：中程度のバイブレーション
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.warning)
            } else {
                // 通常：軽いバイブレーション
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }
        }
    }
    
    private func showFeedbackAnimation(for course: Course) {
        // パルスエフェクト用のState変数を使用
        // この処理は既にEnhancedCourseCellで実装されているshowingCountAnimationで対応
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            // アニメーション処理はEnhancedCourseCellで実装済み
        }
    }
    
    private func loadTimeSlots() {
        guard let semester = viewModel.currentSemester else { return }
        
        let request: NSFetchRequest<PeriodTime> = PeriodTime.fetchRequest()
        request.predicate = NSPredicate(format: "semesterId == %@", semester.semesterId! as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PeriodTime.period, ascending: true)]
        
        let periodTimes = (try? viewModel.managedObjectContext.fetch(request)) ?? []
        
        // デフォルトの時間を保持
        var updatedSlots = ["9:00-10:30", "10:40-12:10", "13:00-14:30", "14:40-16:10", "16:20-17:50"]
        
        if !periodTimes.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            
            // 各時限の時間を更新
            for periodTime in periodTimes {
                let period = Int(periodTime.period)
                if period >= 1 && period <= 5 {
                    let startText = formatter.string(from: periodTime.startTime ?? Date())
                    let endText = formatter.string(from: periodTime.endTime ?? Date())
                    updatedSlots[period - 1] = "\(startText)-\(endText)"
                }
            }
        }
        
        // UIの更新を確実にするためにメインスレッドで実行
        DispatchQueue.main.async {
            self.timeSlots = updatedSlots
        }
    }
}

struct EnhancedCourseCell: View {
    let course: Course?
    let absenceCount: Int
    let statusColor: Color
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    let onTap: () -> Void
    let onLongPress: () -> Void
    
    @State private var isPressed = false
    @State private var isLongPressing = false
    @State private var showingCountAnimation = false
    @State private var previousCount = 0
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                if let course = course {
                    // 上部：科目名（10文字まで2行表示）
                    Text(course.courseName ?? "")
                        .font(.system(size: 9, weight: .medium))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                        .padding(.horizontal, 2)
                    
                    // 中央：欠席数（大きなフォント）
                    ZStack {
                        Text("\(absenceCount)")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                            .scaleEffect(showingCountAnimation ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: absenceCount)
                            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: showingCountAnimation)
                            .onChange(of: absenceCount) { oldValue, newValue in
                                if newValue != previousCount {
                                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                                        showingCountAnimation = true
                                    }
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                            showingCountAnimation = false
                                        }
                                    }
                                    
                                    previousCount = newValue
                                }
                            }
                        
                        // カウントアップエフェクト
                        if showingCountAnimation {
                            Text("+1")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.red)
                                .offset(y: -15)
                                .opacity(showingCountAnimation ? 0 : 1)
                                .animation(.easeOut(duration: 0.5), value: showingCountAnimation)
                        }
                    }
                    .frame(height: 32)
                    
                    // 下部：カラーボックス（数字の下に配置）
                    Spacer(minLength: 4) // カラーボックスの位置を少し下に
                    
                    createColorBoxGrid(course: course, absenceCount: absenceCount, cellWidth: cellWidth)
                        .frame(height: course.isFullYear ? 16 : 8) // 正方形用に高さ調整
                        .padding(.horizontal, 2)
                    
                    Spacer(minLength: 2)
                } else {
                    Text("+")
                        .font(.system(size: 20, weight: .ultraLight))
                        .foregroundColor(.gray.opacity(0.6))
                }
            }
            .frame(width: cellWidth, height: cellHeight)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(course != nil ? Color(.systemBackground) : Color(.systemGray6))
                    .scaleEffect(isPressed ? 0.95 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: isPressed)
                    .overlay(
                        // 左辺全体にカラーライン
                        HStack {
                            if let course = course {
                                Rectangle()
                                    .fill(getCourseColor(course))
                                    .frame(width: 4)
                                    .clipShape(
                                        UnevenRoundedRectangle(
                                            topLeadingRadius: 8,
                                            bottomLeadingRadius: 8,
                                            bottomTrailingRadius: 0,
                                            topTrailingRadius: 0
                                        )
                                    )
                            }
                            Spacer()
                        }
                    )
                    .overlay(
                        // タップ時のオーバーレイエフェクト
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(isPressed ? 0.1 : 0))
                            .animation(.easeInOut(duration: 0.1), value: isPressed)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .interactiveButton(isPressed: isPressed, isLongPressing: isLongPressing)
        .onLongPressGesture {
            if course != nil {
                onLongPress()
            }
        }
        .onTapGesture {
            // タップエフェクト
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
            }
            
            onTap()
        }
    }
    
    private func getCourseColor(_ course: Course) -> Color {
        return DesignSystem.getColor(for: Int(course.colorIndex))
    }
    
    private func createColorBoxGrid(course: Course, absenceCount: Int, cellWidth: CGFloat) -> some View {
        let maxAbsences = Int(course.maxAbsences)
        let boxSize: CGFloat = max(4, (cellWidth - 16) / (course.isFullYear ? 5 : 8)) // 最小サイズを4に増加
        
        return Group {
            if course.isFullYear {
                // 通年：2行5列（正方形）
                VStack(spacing: 1) {
                    HStack(spacing: 1) {
                        ForEach(0..<5, id: \.self) { index in
                            Rectangle()
                                .fill(getColorBoxColor(course: course, index: index, absenceCount: absenceCount))
                                .frame(width: boxSize, height: boxSize) // 完全な正方形
                        }
                    }
                    HStack(spacing: 1) {
                        ForEach(5..<min(10, maxAbsences), id: \.self) { index in
                            Rectangle()
                                .fill(getColorBoxColor(course: course, index: index, absenceCount: absenceCount))
                                .frame(width: boxSize, height: boxSize) // 完全な正方形
                        }
                    }
                }
            } else {
                // 通常：1行（正方形）
                HStack(spacing: 1) {
                    ForEach(0..<min(8, maxAbsences), id: \.self) { index in
                        Rectangle()
                            .fill(getColorBoxColor(course: course, index: index, absenceCount: absenceCount))
                            .frame(width: boxSize, height: boxSize) // 完全な正方形
                    }
                }
            }
        }
    }
    
    private func getColorBoxColor(course: Course, index: Int, absenceCount: Int) -> Color {
        let maxAbsences = Int(course.maxAbsences)
        
        if index < absenceCount {
            // 欠席した回数分
            if absenceCount >= maxAbsences {
                return .red // 限界到達：赤
            } else if absenceCount == maxAbsences - 1 {
                return .orange // 危険圏：オレンジ
            } else {
                return .yellow.opacity(0.8) // 安全圏だが欠席済み：薄い黄色
            }
        } else {
            // まだ欠席していない部分：白色薄透明
            return Color.white.opacity(0.4)
        }
    }
}

#Preview {
    TimetableView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}