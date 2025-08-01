//
//  TimetableView.swift
//  At00
//
//  時間割表示のメイン画面
//

import SwiftUI

struct TimetableView: View {
    @StateObject private var viewModel = AttendanceViewModel()
    @State private var showingCourseDetail = false
    @State private var selectedCourse: Course?
    @State private var showingAddCourse = false
    @State private var selectedTimeSlot: (day: Int, period: Int)?
    @State private var showingErrorAlert = false
    
    private let dayNames = ["月", "火", "水", "木", "金"]
    private let periods = ["1限", "2限", "3限", "4限", "5限"]
    private let timeSlots = ["9:00-10:30", "10:40-12:10", "13:00-14:30", "14:40-16:10", "16:20-17:50"]
    
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
                    AddCourseView(
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
        let cellWidth = (geometry.size.width - 51) / 5 // 左列50px + spacing 1px
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
        VStack(spacing: 2) {
            Text(periods[periodIndex])
                .font(.system(size: 12, weight: .medium))
            Text(timeSlots[periodIndex])
                .font(.system(size: 8))
                .foregroundColor(.secondary)
        }
        .frame(width: 50, height: height)
        .background(Color(.systemGray6))
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
                        showingCourseDetail = true
                    }
                }
            )
        }
    }
    
    private func handleCourseTap(_ course: Course) {
        // ワンタップで欠席記録
        viewModel.recordAbsence(for: course)
        
        // ハプティックフィードバック
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
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
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                if let course = course {
                    // カラーライン
                    HStack {
                        DesignSystem.colorLine(
                            color: getCourseColor(course),
                            width: 3,
                            height: 16
                        )
                        Spacer()
                    }
                    
                    Text(course.courseName ?? "")
                        .font(.system(size: 11, weight: .medium))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        DesignSystem.statusIndicator(
                            color: statusColor,
                            size: 8
                        )
                        
                        Text("\(absenceCount)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(statusColor)
                    }
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                course != nil ? getCourseColor(course!).opacity(0.3) : Color.clear, 
                                lineWidth: 1
                            )
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
        .scaleEffect(isPressed ? 0.98  : 1.0)
        .onTapGesture {
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
        // 仮のカラーインデックス（実際にはCourseモデルにcolorIndexプロパティを追加する必要があります）
        let colorIndex = abs(course.courseName?.hash ?? 0) % DesignSystem.colorPalette.count
        return DesignSystem.getColor(for: colorIndex)
    }
}

#Preview {
    TimetableView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}