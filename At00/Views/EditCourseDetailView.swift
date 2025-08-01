//
//  EditCourseDetailView.swift
//  At00
//
//  授業詳細編集画面
//

import SwiftUI

struct EditCourseDetailView: View {
    let course: Course
    @ObservedObject var viewModel: AttendanceViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var courseName: String
    @State private var totalClasses: Int
    @State private var maxAbsences: Int
    @State private var isNotificationEnabled: Bool
    @State private var selectedColorIndex: Int
    @State private var isFullYear: Bool
    
    init(course: Course, viewModel: AttendanceViewModel) {
        self.course = course
        self.viewModel = viewModel
        self._courseName = State(initialValue: course.courseName ?? "")
        self._totalClasses = State(initialValue: Int(course.totalClasses))
        self._maxAbsences = State(initialValue: Int(course.maxAbsences))
        self._isNotificationEnabled = State(initialValue: course.isNotificationEnabled)
        self._selectedColorIndex = State(initialValue: Int(course.colorIndex))
        self._isFullYear = State(initialValue: course.isFullYear)
    }
    
    private let dayNames = ["", "月", "火", "水", "木", "金", "土", "日"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // ヘッダー
                    VStack(spacing: 16) {
                        HStack {
                            Rectangle()
                                .fill(DesignSystem.getColor(for: selectedColorIndex))
                                .frame(width: 6, height: 80)
                                .cornerRadius(3)
                                .animation(.spring(), value: selectedColorIndex)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("授業名", text: $courseName)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .textFieldStyle(PlainTextFieldStyle())
                                
                                Text("\(dayName)曜日 \(course.period)限")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        // 現在の出席状況表示
                        HStack(spacing: 20) {
                            VStack {
                                Text("\(viewModel.getAbsenceCount(for: course))")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(viewModel.getStatusColor(for: course))
                                
                                Text("現在の欠席")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack {
                                Text("\(viewModel.getRemainingAbsences(for: course))")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.green)
                                
                                Text("残り可能")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .cardStyle()
                    
                    // 編集フォーム
                    VStack(spacing: 20) {
                        // 授業設定
                        VStack(alignment: .leading, spacing: 16) {
                            Text("授業設定")
                                .font(.headline)
                            
                            VStack(spacing: 12) {
                                HStack {
                                    Text("総授業回数")
                                    Spacer()
                                    Stepper(value: $totalClasses, in: 1...50) {
                                        Text("\(totalClasses)回")
                                            .font(.system(size: 16, weight: .medium))
                                    }
                                }
                                
                                HStack {
                                    Text("最大欠席可能")
                                    Spacer()
                                    Stepper(value: $maxAbsences, in: 1...20) {
                                        Text("\(maxAbsences)回")
                                            .font(.system(size: 16, weight: .medium))
                                    }
                                }
                                
                                HStack {
                                    Text("通年科目")
                                    Spacer()
                                    Toggle("", isOn: $isFullYear)
                                }
                                
                                HStack {
                                    Text("通知")
                                    Spacer()
                                    Toggle("", isOn: $isNotificationEnabled)
                                }
                            }
                        }
                        .padding()
                        .cardStyle()
                        
                        // カラー選択
                        VStack(alignment: .leading, spacing: 16) {
                            Text("カラー")
                                .font(.headline)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                                ForEach(0..<12, id: \.self) { index in
                                    Button {
                                        withAnimation(.spring(response: 0.3)) {
                                            selectedColorIndex = index
                                        }
                                    } label: {
                                        ZStack {
                                            Circle()
                                                .fill(DesignSystem.getColor(for: index))
                                                .frame(width: 40, height: 40)
                                            
                                            if selectedColorIndex == index {
                                                Circle()
                                                    .stroke(Color.primary, lineWidth: 3)
                                                    .frame(width: 40, height: 40)
                                                
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(.white)
                                                    .font(.system(size: 12, weight: .bold))
                                            }
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding()
                        .cardStyle()
                        
                        // 危険なアクション
                        VStack(alignment: .leading, spacing: 16) {
                            Text("危険なアクション")
                                .font(.headline)
                                .foregroundColor(.red)
                            
                            Button("この授業を削除") {
                                viewModel.deleteCourse(course)
                                dismiss()
                            }
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .padding()
                        .cardStyle()
                    }
                }
                .padding()
            }
            .navigationTitle("授業編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveChanges()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(courseName.isEmpty)
                }
            }
        }
    }
    
    private var dayName: String {
        let index = Int(course.dayOfWeek)
        return index > 0 && index < dayNames.count ? dayNames[index] : ""
    }
    
    private func saveChanges() {
        course.courseName = courseName
        course.totalClasses = Int16(totalClasses)
        course.maxAbsences = Int16(maxAbsences)
        course.isNotificationEnabled = isNotificationEnabled
        course.colorIndex = Int16(selectedColorIndex)
        course.isFullYear = isFullYear
        
        viewModel.save()
        viewModel.loadTimetable()
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let course = Course(context: context)
    course.courseName = "プログラミング基礎"
    course.dayOfWeek = 1
    course.period = 1
    course.totalClasses = 15
    course.maxAbsences = 5
    course.colorIndex = 0
    
    return EditCourseDetailView(course: course, viewModel: AttendanceViewModel(persistenceController: .preview))
}