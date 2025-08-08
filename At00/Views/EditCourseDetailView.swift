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
    @State private var absenceRecords: [AttendanceRecord] = []
    @State private var tempAddedRecords: [TempAbsenceRecord] = [] // 一時的に追加された記録
    @State private var deletedRecords: Set<AttendanceRecord> = [] // 削除予定の記録
    @State private var selectedAbsenceDate: Date = Date()
    @State private var showingAddAbsenceAlert = false
    @State private var showingDuplicateNameAlert = false
    @State private var duplicateAlertMessage = ""
    @State private var showingOutsidePeriodAlert = false
    @State private var outsidePeriodMessage = ""
    
    // 一時的な欠席記録の構造体
    struct TempAbsenceRecord: Identifiable {
        let id = UUID()
        let date: Date
        let type: AttendanceType
        let memo: String
    }
    
    init(course: Course, viewModel: AttendanceViewModel) {
        self.course = course
        self.viewModel = viewModel
        self._courseName = State(initialValue: course.courseName ?? "")
        self._totalClasses = State(initialValue: Int(course.totalClasses))
        self._maxAbsences = State(initialValue: Int(course.maxAbsences))
        self._selectedColorIndex = State(initialValue: Int(course.colorIndex))
    }
    
    private let dayNames = ["", "月", "火", "水", "木", "金", "土", "日"]
    
    var body: some View {
        // ViewModelの初期化状態をチェック（NavigationViewなしで実装）
        Group {
            if !viewModel.isInitialized || viewModel.currentSemester == nil {
                // 統一されたローディング表示
                DesignSystem.LoadingView(message: "読み込み中...")
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
        .sheet(isPresented: $showingAddAbsenceAlert) {
            AddAbsenceRecordSheet(
                selectedDate: $selectedAbsenceDate,
                currentSemester: viewModel.currentSemester,
                onAdd: {
                    addAbsenceRecord()
                    if !showingOutsidePeriodAlert {
                        showingAddAbsenceAlert = false
                    }
                },
                onCancel: {
                    showingAddAbsenceAlert = false
                }
            )
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("キャンセル") {
                    // 全ての一時的変更を破棄
                    discardTempChanges()
                    dismiss()
                }
                .secondaryButtonStyle()
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") {
                    saveChanges()
                    dismiss()
                }
                .primaryButtonStyle(isDisabled: courseName.isEmpty)
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
        .alert("授業名の重複エラー", isPresented: $showingDuplicateNameAlert) {
            Button("OK") { }
        } message: {
            Text(duplicateAlertMessage)
        }
        .alert("学期期間外エラー", isPresented: $showingOutsidePeriodAlert) {
            Button("OK") { }
        } message: {
            Text(outsidePeriodMessage)
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
                    .keyboardType(.default)
                    .disableAutocorrection(true)
                
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
        .shadow(color: DesignSystem.adaptiveShadowColor, radius: 4, x: 0, y: 2)
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
                
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: DesignSystem.adaptiveShadowColor, radius: 4, x: 0, y: 2)
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
        .shadow(color: DesignSystem.adaptiveShadowColor, radius: 4, x: 0, y: 2)
    }
    
    private var absenceRecordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("欠席記録")
                    .font(.system(size: 17, weight: .semibold))
                
                Spacer()
                
                Button {
                    selectedAbsenceDate = Date()
                    showingAddAbsenceAlert = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
                
                Text("\(displayedRecordsCount)件")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
            }
            
            if displayedRecords.isEmpty {
                AbsenceRecordsEmptyStateView()
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 6) {
                    // 既存の記録（削除予定でないもの）
                    ForEach(absenceRecords.filter { !deletedRecords.contains($0) }, id: \.recordId) { record in
                        absenceRecordRow(record: record, isExisting: true)
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                    }
                    
                    // 一時的に追加された記録
                    ForEach(tempAddedRecords) { tempRecord in
                        tempAbsenceRecordRow(tempRecord: tempRecord)
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: displayedRecordsCount)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: DesignSystem.adaptiveShadowColor, radius: 4, x: 0, y: 2)
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
    
    private func absenceRecordRow(record: AttendanceRecord, isExisting: Bool) -> some View {
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
                if isExisting {
                    markRecordForDeletion(record)
                }
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
    
    private func tempAbsenceRecordRow(tempRecord: TempAbsenceRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(formatDate(tempRecord.date))
                    .font(.system(size: 15, weight: .medium))
                
                HStack(spacing: 4) {
                    Text(tempRecord.type.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("(未保存)")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            Button {
                removeTempRecord(tempRecord)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.red)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground).opacity(0.8))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Helper Properties
    
    // 表示用の記録数（既存の記録 - 削除予定 + 一時追加）
    private var displayedRecordsCount: Int {
        let existingCount = absenceRecords.filter { !deletedRecords.contains($0) }.count
        return existingCount + tempAddedRecords.count
    }
    
    // 表示用の記録が空かどうか
    private var displayedRecords: [Any] {
        let existing = absenceRecords.filter { !deletedRecords.contains($0) }
        return existing + tempAddedRecords
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
    
    // MARK: - Temporary Change Management
    
    private func markRecordForDeletion(_ record: AttendanceRecord) {
        _ = withAnimation(.easeInOut(duration: 0.3)) {
            deletedRecords.insert(record)
        }
        
        // 軽いハプティックフィードバック
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func removeTempRecord(_ tempRecord: TempAbsenceRecord) {
        withAnimation(.easeInOut(duration: 0.3)) {
            tempAddedRecords.removeAll { $0.id == tempRecord.id }
        }
        
        // 軽いハプティックフィードバック
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func discardTempChanges() {
        // 全ての一時的な変更を破棄
        deletedRecords.removeAll()
        tempAddedRecords.removeAll()
        
        // 元の値に戻す
        courseName = course.courseName ?? ""
        totalClasses = Int(course.totalClasses)
        maxAbsences = Int(course.maxAbsences)
        selectedColorIndex = Int(course.colorIndex)
    }
    
    private func addAbsenceRecord() {
        // 期間外日付チェック
        if !viewModel.isDateWithinCurrentSemesterPeriod(selectedAbsenceDate) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy年MM月dd日"
            let selectedDateString = formatter.string(from: selectedAbsenceDate)
            
            if let semesterName = viewModel.currentSemester?.name,
               let startDate = viewModel.currentSemester?.startDate,
               let endDate = viewModel.currentSemester?.endDate {
                let startDateString = formatter.string(from: startDate)
                let endDateString = formatter.string(from: endDate)
                
                outsidePeriodMessage = "選択された日付（\(selectedDateString)）は、現在の学期「\(semesterName)」の期間外です。\n\n有効期間: \(startDateString) 〜 \(endDateString)\n\n学期期間内の日付を選択してください。"
            } else {
                outsidePeriodMessage = "選択された日付（\(selectedDateString)）は学期期間外です。学期期間内の日付を選択してください。"
            }
            
            showingOutsidePeriodAlert = true
            
            // エラーハプティックフィードバック
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.error)
            
            return
        }
        
        // 一時的な記録として追加（まだ保存しない）
        let tempRecord = TempAbsenceRecord(
            date: selectedAbsenceDate,
            type: .absent,
            memo: "手動追加"
        )
        
        withAnimation(.easeInOut(duration: 0.3)) {
            tempAddedRecords.append(tempRecord)
        }
        
        // 成功ハプティックフィードバック
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // 次回のためにリセット
        selectedAbsenceDate = Date()
    }
    
    private func saveChanges() {
        // 授業名が変更された場合、重複チェック
        if courseName != course.courseName {
            // 全学期を通じて同名の授業が既に存在するかチェック（自分自身を除く）
            let request: NSFetchRequest<Course> = Course.fetchRequest()
            request.predicate = NSPredicate(
                format: "courseName == %@ AND courseId != %@",
                courseName,
(course.courseId ?? UUID()) as CVarArg
            )
            request.fetchLimit = 1
            
            do {
                let count = try viewModel.managedObjectContext.count(for: request)
                if count > 0 {
                    // どのシートに存在するか確認
                    if let semester = viewModel.currentSemester {
                        let currentSemesterRequest: NSFetchRequest<Course> = Course.fetchRequest()
                        currentSemesterRequest.predicate = NSPredicate(
                            format: "semester == %@ AND courseName == %@ AND courseId != %@",
                            semester,
                            courseName,
            (course.courseId ?? UUID()) as CVarArg
                        )
                        currentSemesterRequest.fetchLimit = 1
                        
                        let currentSemesterCount = try viewModel.managedObjectContext.count(for: currentSemesterRequest)
                        if currentSemesterCount > 0 {
                            duplicateAlertMessage = "「\(courseName)」という名前の授業は、この時間割シートに既に存在します。\n\n異なる授業名を使用してください。"
                        } else {
                            duplicateAlertMessage = "「\(courseName)」という名前の授業は、別の時間割シートに既に存在します。\n\n同じ授業名を複数のシートで使用することはできません。異なる授業名を使用してください。"
                        }
                    }
                    showingDuplicateNameAlert = true
                    return
                }
            } catch {
                print("授業名重複チェックエラー: \(error)")
            }
        }
        
        // 1. 削除予定の記録を実際に削除
        for record in deletedRecords {
            viewModel.managedObjectContext.delete(record)
        }
        
        // 2. 一時的に追加された記録を実際に保存
        for tempRecord in tempAddedRecords {
            viewModel.addAbsenceRecord(
                for: course,
                date: tempRecord.date,
                type: tempRecord.type,
                memo: tempRecord.memo
            )
        }
        
        // 3. 同名の他の授業も同じ設定に更新
        if let courseName = course.courseName {
            let courseRequest: NSFetchRequest<Course> = Course.fetchRequest()
            courseRequest.predicate = NSPredicate(format: "courseName == %@", courseName)
            
            do {
                let sameCourses = try viewModel.managedObjectContext.fetch(courseRequest)
                for sameCourse in sameCourses {
                    sameCourse.courseName = self.courseName
                    sameCourse.totalClasses = Int16(totalClasses)
                    sameCourse.maxAbsences = Int16(maxAbsences)
                    sameCourse.colorIndex = Int16(selectedColorIndex)
                }
            } catch {
                print("同名授業の更新エラー: \(error)")
            }
        } else {
            // 単一授業の更新
            course.courseName = courseName
            course.totalClasses = Int16(totalClasses)
            course.maxAbsences = Int16(maxAbsences)
            course.colorIndex = Int16(selectedColorIndex)
        }
        
        
        // 3. 一時的な変更をクリア
        deletedRecords.removeAll()
        tempAddedRecords.removeAll()
        
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

// MARK: - AddAbsenceRecordSheet

struct AddAbsenceRecordSheet: View {
    @Binding var selectedDate: Date
    let currentSemester: Semester?
    let onAdd: () -> Void
    let onCancel: () -> Void
    
    private var isDateValid: Bool {
        guard let semester = currentSemester,
              let startDate = semester.startDate,
              let endDate = semester.endDate else {
            return false
        }
        
        let calendar = Calendar.current
        let checkDate = calendar.startOfDay(for: selectedDate)
        let semesterStart = calendar.startOfDay(for: startDate)
        let semesterEnd = calendar.startOfDay(for: endDate)
        
        return checkDate >= semesterStart && checkDate <= semesterEnd
    }
    
    private var dateRangeText: String {
        guard let semester = currentSemester,
              let startDate = semester.startDate,
              let endDate = semester.endDate else {
            return "学期情報が取得できません"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        let start = formatter.string(from: startDate)
        let end = formatter.string(from: endDate)
        
        return "学期期間: \(start) 〜 \(end)"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text("欠席記録を追加")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("欠席した日付を選択してください")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // 学期期間情報
                VStack(spacing: 8) {
                    if let semesterName = currentSemester?.name {
                        Text("現在の学期: \(semesterName)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                    
                    Text(dateRangeText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !isDateValid {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("選択された日付は学期期間外です")
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.top, 4)
                    }
                }
                .padding()
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
                
                DatePicker(
                    "欠席日",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(GraphicalDatePickerStyle())
                .padding()
                .background(isDateValid ? Color(.secondarySystemBackground) : Color(.systemRed).opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isDateValid ? Color.clear : Color.red, lineWidth: 1)
                )
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button("キャンセル") {
                        onCancel()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(10)
                    
                    Button("追加") {
                        onAdd()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isDateValid ? Color.blue : Color.gray)
                    .cornerRadius(10)
                    .disabled(!isDateValid)
                }
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
}