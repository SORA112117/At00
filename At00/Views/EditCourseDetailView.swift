//
//  EditCourseDetailView.swift
//  At00
//
//  授業詳細編集画面 - モダン＆シンプルデザイン
//

import SwiftUI
import CoreData

struct EditCourseDetailView: View {
    let course: Course
    @ObservedObject var viewModel: AttendanceViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var courseName: String
    @State private var totalClasses: Int
    @State private var maxAbsences: Int
    @State private var selectedColorIndex: Int
    @State private var isFullYear: Bool
    @State private var absenceRecords: [AttendanceRecord] = []
    @State private var showingDeleteAlert = false
    @State private var recordToDelete: AttendanceRecord?
    @State private var deletedRecords: Set<AttendanceRecord> = []
    
    init(course: Course, viewModel: AttendanceViewModel) {
        self.course = course
        self.viewModel = viewModel
        self._courseName = State(initialValue: course.courseName ?? "")
        self._totalClasses = State(initialValue: Int(course.totalClasses))
        self._maxAbsences = State(initialValue: Int(course.maxAbsences))
        self._selectedColorIndex = State(initialValue: Int(course.colorIndex))
        self._isFullYear = State(initialValue: course.isFullYear)
    }
    
    private let dayNames = ["", "月", "火", "水", "木", "金", "土", "日"]
    
    var body: some View {
        // ViewModelの初期化状態をチェック（NavigationViewなしで実装）
        Group {
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
                // メインコンテンツ
                ScrollView {
                    VStack(spacing: 16) {
                        // ヘッダーセクション
                        headerSection
                        
                        // 基本設定セクション
                        basicSettingsSection
                        
                        // カラー選択セクション
                        colorSelectionSection
                        
                        // 欠席記録セクション
                        absenceRecordsSection
                        
                        // 削除セクション
                        deleteSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemGroupedBackground))
            }
        }
        .navigationTitle("授業編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("キャンセル") {
                    // 削除予定の記録をリセット
                    deletedRecords.removeAll()
                    dismiss()
                }
                .foregroundColor(.secondary)
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
        .onAppear {
            print("EditCourseDetailView appeared - isInitialized: \(viewModel.isInitialized), currentSemester: \(viewModel.currentSemester?.name ?? "nil")")
            // ViewModelが初期化されてから欠席記録を読み込み
            if viewModel.isInitialized && viewModel.currentSemester != nil {
                loadAbsenceRecords()
            }
        }
        .onChange(of: viewModel.isInitialized) { _, isInitialized in
            print("EditCourseDetailView isInitialized changed to: \(isInitialized)")
            // ViewModelの初期化完了時に欠席記録を読み込み
            if isInitialized && viewModel.currentSemester != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    loadAbsenceRecords()
                }
            }
        }
        .alert("記録を削除", isPresented: $showingDeleteAlert) {
            Button("削除", role: .destructive) {
                if let record = recordToDelete {
                    deleteAbsenceRecord(record)
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("この欠席記録を削除しますか？")
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        HStack(spacing: 12) {
            // カラーライン
            RoundedRectangle(cornerRadius: 3)
                .fill(DesignSystem.getColor(for: selectedColorIndex))
                .frame(width: 4, height: 50)
                .animation(.spring(response: 0.4), value: selectedColorIndex)
            
            VStack(alignment: .leading, spacing: 6) {
                TextField("授業名", text: $courseName)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .textFieldStyle(PlainTextFieldStyle())
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onTapGesture {
                        // TextFieldを確実にアクティブにする
                    }
                
                Text("\(dayName)曜日 \(course.period)限")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("\(viewModel.getAbsenceCount(for: course))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("欠席")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var basicSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("基本設定")
                .font(.system(size: 17, weight: .semibold))
            
            VStack(spacing: 0) {
                settingRow(title: "総授業回数", value: "\(totalClasses)回") {
                    Stepper("", value: $totalClasses, in: 1...50)
                        .labelsHidden()
                }
                
                Divider()
                    .padding(.leading, 12)
                
                settingRow(title: "最大欠席可能", value: "\(maxAbsences)回") {
                    Stepper("", value: $maxAbsences, in: 1...20)
                        .labelsHidden()
                }
                
                Divider()
                    .padding(.leading, 12)
                
                settingRow(title: "通年科目", value: "") {
                    Toggle("", isOn: $isFullYear)
                        .labelsHidden()
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var colorSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("カラー")
                .font(.system(size: 17, weight: .semibold))
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                ForEach(0..<12, id: \.self) { index in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedColorIndex = index
                        }
                    } label: {
                        Circle()
                            .fill(DesignSystem.getColor(for: index))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary, lineWidth: selectedColorIndex == index ? 2.5 : 0)
                                    .scaleEffect(selectedColorIndex == index ? 1.1 : 1.0)
                                    .animation(.spring(response: 0.3), value: selectedColorIndex)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var absenceRecordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("欠席記録")
                    .font(.system(size: 17, weight: .semibold))
                
                Spacer()
                
                Text("\(absenceRecords.count)件")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if absenceRecords.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "checkmark.circle")
                        .font(.title3)
                        .foregroundColor(.green)
                    
                    Text("欠席記録はありません")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                LazyVStack(spacing: 6) {
                    ForEach(absenceRecords, id: \.recordId) { record in
                        absenceRecordRow(record: record)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var deleteSection: some View {
        Button {
            viewModel.deleteCourse(course)
            dismiss()
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("授業を削除")
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(Color.red)
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func settingRow<Content: View>(title: String, value: String, @ViewBuilder control: () -> Content) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                
                if !value.isEmpty {
                    Text(value)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            control()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }
    
    private func absenceRecordRow(record: AttendanceRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(formatDate(record.date ?? Date()))
                    .font(.system(size: 15, weight: .medium))
                
                Text(AttendanceType(rawValue: record.type ?? "")?.displayName ?? "欠席")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                recordToDelete = record
                showingDeleteAlert = true
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.red)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    // MARK: - Helper Methods
    
    private var dayName: String {
        let index = Int(course.dayOfWeek)
        return index > 0 && index < dayNames.count ? dayNames[index] : ""
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日(E)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
    
    private func loadAbsenceRecords() {
        // 同名科目のすべての欠席記録を取得
        guard let courseName = course.courseName else { return }
        
        let request: NSFetchRequest<AttendanceRecord> = AttendanceRecord.fetchRequest()
        let courseRequest: NSFetchRequest<Course> = Course.fetchRequest()
        courseRequest.predicate = NSPredicate(format: "courseName == %@", courseName)
        
        do {
            let allSameNameCourses = try viewModel.managedObjectContext.fetch(courseRequest)
            let courseIds = allSameNameCourses.map { $0.objectID }
            
            request.predicate = NSPredicate(
                format: "course IN %@ AND type IN %@",
                courseIds,
                AttendanceType.allCases.filter { $0.affectsCredit }.map { $0.rawValue }
            )
            request.sortDescriptors = [NSSortDescriptor(keyPath: \AttendanceRecord.date, ascending: false)]
            
            absenceRecords = try viewModel.managedObjectContext.fetch(request)
        } catch {
            print("欠席記録の読み込みエラー: \(error)")
        }
    }
    
    private func deleteAbsenceRecord(_ record: AttendanceRecord) {
        // 削除予定として記録（実際にはまだ削除しない）
        deletedRecords.insert(record)
        
        // 表示用のリストから削除
        if let index = absenceRecords.firstIndex(of: record) {
            absenceRecords.remove(at: index)
        }
    }
    
    private func saveChanges() {
        // 削除予定の記録を実際に削除
        for record in deletedRecords {
            viewModel.managedObjectContext.delete(record)
        }
        
        // コース情報を更新
        course.courseName = courseName
        course.totalClasses = Int16(totalClasses)
        course.maxAbsences = Int16(maxAbsences)
        course.colorIndex = Int16(selectedColorIndex)
        course.isFullYear = isFullYear
        
        viewModel.save()
        viewModel.loadTimetable()
        
        // コースデータの更新を通知
        NotificationCenter.default.post(name: .courseDataDidChange, object: nil)
        NotificationCenter.default.post(name: .statisticsDataDidChange, object: nil)
        NotificationCenter.default.post(name: .attendanceDataDidChange, object: nil)
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