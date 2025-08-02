//
//  SettingsView.swift
//  At00
//
//  設定画面
//

import SwiftUI
import CoreData
import UserNotifications
import LocalAuthentication

struct SettingsView: View {
    @StateObject private var viewModel = AttendanceViewModel()
    @State private var showingNewSemester = false
    @State private var showingDataExport = false
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        NavigationView {
            List {
                // 学期管理セクション
                Section("学期管理") {
                    if let semester = viewModel.currentSemester {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(semester.name ?? "")
                                .font(.headline)
                            Text("開始: \(semester.startDate?.formatted(date: .abbreviated, time: .omitted) ?? "")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("終了: \(semester.endDate?.formatted(date: .abbreviated, time: .omitted) ?? "")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    Button("新しい学期を作成") {
                        showingNewSemester = true
                    }
                    .foregroundColor(.blue)
                }
                
                // 出席設定セクション
                Section("出席設定") {
                    NavigationLink("授業管理") {
                        CourseManagementView(viewModel: viewModel)
                    }
                    
                    NavigationLink("時限時間設定") {
                        PeriodTimeSettingsView()
                    }
                    
                    NavigationLink("通知設定") {
                        NotificationSettingsView()
                    }
                }
                
                // 外観・セキュリティセクション
                Section("外観・セキュリティ") {
                    NavigationLink("外観設定") {
                        AppearanceSettingsView()
                    }
                    
                    NavigationLink("セキュリティ設定") {
                        SecuritySettingsView()
                    }
                }
                
                // データ管理セクション
                Section("データ管理") {
                    Button("データをエクスポート") {
                        showingDataExport = true
                    }
                    .foregroundColor(.blue)
                    
                    Button("データをインポート") {
                        // データインポート機能（実装予定）
                    }
                    .foregroundColor(.blue)
                    
                    Button("すべてのデータを削除") {
                        showingDeleteConfirmation = true
                    }
                    .foregroundColor(.red)
                }
                
                // アプリ情報セクション
                Section("アプリ情報") {
                    HStack {
                        Text("バージョン")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    NavigationLink("利用規約") {
                        TermsOfServiceView()
                    }
                    
                    NavigationLink("プライバシーポリシー") {
                        PrivacyPolicyView()
                    }
                    
                    NavigationLink("サポート") {
                        SupportView()
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingNewSemester) {
                NewSemesterView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingDataExport) {
                DataExportView()
            }
            .alert("データ削除の確認", isPresented: $showingDeleteConfirmation) {
                Button("削除", role: .destructive) {
                    deleteAllData()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("すべてのデータが削除されます。この操作は取り消せません。")
            }
        }
    }
    
    private func deleteAllData() {
        let context = viewModel.managedObjectContext
        
        // すべてのエンティティを削除
        deleteAllEntities(of: AttendanceRecord.self, in: context)
        deleteAllEntities(of: Course.self, in: context)
        deleteAllEntities(of: Semester.self, in: context)
        deleteAllEntities(of: PeriodTime.self, in: context)
        
        // 変更を保存
        do {
            try context.save()
            
            // ViewModelを再初期化して学期を再作成
            viewModel.setupSemesters()
            viewModel.loadCurrentSemester()
            viewModel.loadTimetable()
            
        } catch {
            print("データ削除エラー: \(error)")
        }
    }
    
    private func deleteAllEntities<T: NSManagedObject>(of entityType: T.Type, in context: NSManagedObjectContext) {
        let fetchRequest = NSFetchRequest<T>(entityName: String(describing: entityType))
        
        do {
            let entities = try context.fetch(fetchRequest)
            for entity in entities {
                context.delete(entity)
            }
        } catch {
            print("\(entityType)の削除エラー: \(error)")
        }
    }
}

struct NewSemesterView: View {
    @ObservedObject var viewModel: AttendanceViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var semesterName = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .month, value: 4, to: Date()) ?? Date()
    
    var body: some View {
        NavigationView {
            Form {
                Section("学期情報") {
                    TextField("学期名", text: $semesterName)
                        .textInputAutocapitalization(.words)
                    
                    DatePicker("開始日", selection: $startDate, displayedComponents: .date)
                    
                    DatePicker("終了日", selection: $endDate, displayedComponents: .date)
                }
                
                Section {
                    Text("新しい学期を作成すると、現在の学期が非アクティブになります。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("新学期作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("作成") {
                        createNewSemester()
                        dismiss()
                    }
                    .disabled(semesterName.isEmpty || startDate >= endDate)
                }
            }
        }
    }
    
    private func createNewSemester() {
        // 新学期作成の実装
        let context = viewModel.managedObjectContext
        
        // 既存の学期を非アクティブにする
        let existingSemesters = try? context.fetch(Semester.fetchRequest())
        existingSemesters?.forEach { $0.isActive = false }
        
        // 新しい学期を作成
        let newSemester = Semester(context: context)
        newSemester.semesterId = UUID()
        newSemester.name = semesterName
        newSemester.startDate = startDate
        newSemester.endDate = endDate
        newSemester.isActive = true
        newSemester.createdAt = Date()
        
        try? context.save()
        viewModel.loadCurrentSemester()
        viewModel.loadTimetable()
    }
}

struct CourseManagementView: View {
    @ObservedObject var viewModel: AttendanceViewModel
    
    var body: some View {
        List {
            ForEach(getAllCourses(), id: \.courseId) { course in
                NavigationLink {
                    CourseEditView(course: course, viewModel: viewModel)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(course.courseName ?? "")
                            .font(.headline)
                        
                        Text("\(dayName(for: course.dayOfWeek))曜日 \(course.period)限")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("欠席: \(viewModel.getAbsenceCount(for: course))回")
                                .font(.caption)
                                .foregroundColor(.red)
                            
                            Spacer()
                            
                            Circle()
                                .fill(viewModel.getStatusColor(for: course))
                                .frame(width: 12, height: 12)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .onDelete(perform: deleteCourses)
        }
        .navigationTitle("授業管理")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func getAllCourses() -> [Course] {
        guard let semester = viewModel.currentSemester else { return [] }
        
        let request: NSFetchRequest<Course> = Course.fetchRequest()
        request.predicate = NSPredicate(format: "semester == %@", semester)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Course.dayOfWeek, ascending: true),
            NSSortDescriptor(keyPath: \Course.period, ascending: true)
        ]
        
        return (try? viewModel.managedObjectContext.fetch(request)) ?? []
    }
    
    private func dayName(for dayOfWeek: Int16) -> String {
        let days = ["", "月", "火", "水", "木", "金", "土", "日"]
        let index = Int(dayOfWeek)
        return index > 0 && index < days.count ? days[index] : ""
    }
    
    private func deleteCourses(offsets: IndexSet) {
        let courses = getAllCourses()
        for index in offsets {
            viewModel.deleteCourse(courses[index])
        }
    }
}

struct CourseEditView: View {
    let course: Course
    @ObservedObject var viewModel: AttendanceViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var courseName: String
    @State private var totalClasses: Int
    @State private var maxAbsences: Int
    @State private var isNotificationEnabled: Bool
    
    init(course: Course, viewModel: AttendanceViewModel) {
        self.course = course
        self.viewModel = viewModel
        self._courseName = State(initialValue: course.courseName ?? "")
        self._totalClasses = State(initialValue: Int(course.totalClasses))
        self._maxAbsences = State(initialValue: Int(course.maxAbsences))
        self._isNotificationEnabled = State(initialValue: course.isNotificationEnabled)
    }
    
    var body: some View {
        Form {
            Section("授業情報") {
                TextField("授業名", text: $courseName)
                    .inputFieldStyle()
                
                HStack {
                    Text("曜日・時限")
                    Spacer()
                    Text("\(dayName)曜日 \(course.period)限")
                        .foregroundColor(.secondary)
                }
            }
            
            Section("授業設定") {
                Stepper("総授業回数: \(totalClasses)回", value: $totalClasses, in: 1...30)
                
                Stepper("最大欠席可能: \(maxAbsences)回", value: $maxAbsences, in: 1...15)
                
                Toggle("通知を有効にする", isOn: $isNotificationEnabled)
            }
            
            Section("出席状況") {
                HStack {
                    Text("現在の欠席回数")
                    Spacer()
                    Text("\(viewModel.getAbsenceCount(for: course))回")
                        .foregroundColor(.red)
                }
                
                HStack {
                    Text("残り欠席可能回数")
                    Spacer()
                    Text("\(viewModel.getRemainingAbsences(for: course))回")
                        .foregroundColor(viewModel.getStatusColor(for: course))
                }
            }
        }
        .navigationTitle("授業編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") {
                    saveChanges()
                    dismiss()
                }
            }
        }
    }
    
    private var dayName: String {
        let days = ["", "月", "火", "水", "木", "金", "土", "日"]
        let index = Int(course.dayOfWeek)
        return index > 0 && index < days.count ? days[index] : ""
    }
    
    private func saveChanges() {
        course.courseName = courseName
        course.totalClasses = Int16(totalClasses)
        course.maxAbsences = Int16(maxAbsences)
        course.isNotificationEnabled = isNotificationEnabled
        
        viewModel.save()
    }
}

// MARK: - 強化された設定ビュー群

struct NotificationSettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("absentLimitNotification") private var absentLimitNotification = true
    @AppStorage("reminderNotification") private var reminderNotification = false
    @AppStorage("reminderTime") private var reminderTimeData = Data()
    @AppStorage("reminderFrequency") private var reminderFrequency = "daily"
    
    @State private var reminderTime = Date()
    @State private var showingReminderSettings = false
    
    let reminderFrequencies = [
        ("daily", "毎日"),
        ("weekly", "週1回"),
        ("monthly", "月1回")
    ]
    
    var body: some View {
        List {
            Section("基本通知設定") {
                Toggle("プッシュ通知を有効にする", isOn: $notificationsEnabled)
                    .onChange(of: notificationsEnabled) { _, newValue in
                        if newValue {
                            requestNotificationPermission()
                        }
                    }
                
                if notificationsEnabled {
                    Toggle("欠席回数が上限に近づいたら通知", isOn: $absentLimitNotification)
                }
            }
            
            if notificationsEnabled {
                Section("リマインダー通知") {
                    Toggle("入力をお忘れですか？通知", isOn: $reminderNotification)
                        .onChange(of: reminderNotification) { _, newValue in
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingReminderSettings = newValue
                            }
                        }
                    
                    if showingReminderSettings && reminderNotification {
                        DatePicker("通知時刻", selection: $reminderTime, displayedComponents: .hourAndMinute)
                            .onChange(of: reminderTime) { _, newValue in
                                saveReminderTime(newValue)
                            }
                        
                        Picker("頻度", selection: $reminderFrequency) {
                            ForEach(reminderFrequencies, id: \.0) { frequency, name in
                                Text(name).tag(frequency)
                            }
                        }
                        
                        Text("設定した時刻に出席記録の入力を促す通知が届きます")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("通知設定")
        .onAppear {
            loadReminderTime()
            showingReminderSettings = reminderNotification
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if !granted {
                    notificationsEnabled = false
                }
            }
        }
    }
    
    private func saveReminderTime(_ time: Date) {
        if let encoded = try? JSONEncoder().encode(time) {
            reminderTimeData = encoded
        }
    }
    
    private func loadReminderTime() {
        if let decoded = try? JSONDecoder().decode(Date.self, from: reminderTimeData) {
            reminderTime = decoded
        } else {
            reminderTime = Calendar.current.date(from: DateComponents(hour: 18, minute: 0)) ?? Date()
        }
    }
}

struct AppearanceSettingsView: View {
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    
    let appearanceModes = [
        ("system", "システム設定に従う"),
        ("light", "ライトモード"),
        ("dark", "ダークモード")
    ]
    
    var body: some View {
        List {
            Section("外観設定") {
                Picker("テーマ", selection: $appearanceMode) {
                    ForEach(appearanceModes, id: \.0) { mode, name in
                        Text(name).tag(mode)
                    }
                }
                .onChange(of: appearanceMode) { _, newValue in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        applyAppearanceMode(newValue)
                    }
                }
                
                Text("アプリの外観を設定できます。システム設定に従う場合、デバイスの設定に応じて自動的に切り替わります。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("外観設定")
    }
    
    private func applyAppearanceMode(_ mode: String) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        
        switch mode {
        case "light":
            window.overrideUserInterfaceStyle = .light
        case "dark":
            window.overrideUserInterfaceStyle = .dark
        default:
            window.overrideUserInterfaceStyle = .unspecified
        }
    }
}

struct SecuritySettingsView: View {
    @AppStorage("passcodeEnabled") private var passcodeEnabled = false
    @AppStorage("biometricEnabled") private var biometricEnabled = false
    @State private var showingPasscodeSetup = false
    @State private var biometricType: String = ""
    
    var body: some View {
        List {
            Section("セキュリティ設定") {
                Toggle("パスコードロック", isOn: $passcodeEnabled)
                    .onChange(of: passcodeEnabled) { _, newValue in
                        if newValue {
                            showingPasscodeSetup = true
                        }
                    }
                
                if passcodeEnabled {
                    Toggle("\(biometricType)認証", isOn: $biometricEnabled)
                        .disabled(biometricType.isEmpty)
                }
                
                if passcodeEnabled || biometricEnabled {
                    Text("アプリを開く際に認証が必要になります。セキュリティを向上させるために設定をお勧めします。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("セキュリティ設定")
        .sheet(isPresented: $showingPasscodeSetup) {
            PasscodeSetupView(isPresented: $showingPasscodeSetup)
        }
        .onAppear {
            checkBiometricAvailability()
        }
    }
    
    private func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID:
                biometricType = "Face ID"
            case .touchID:
                biometricType = "Touch ID"
            default:
                biometricType = "生体"
            }
        } else {
            biometricType = ""
        }
    }
}

struct PasscodeSetupView: View {
    @Binding var isPresented: Bool
    @State private var passcode = ""
    @State private var confirmPasscode = ""
    @State private var step: SetupStep = .initial
    @State private var showingError = false
    @State private var errorMessage = ""
    
    enum SetupStep {
        case initial, confirm, complete
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text(stepTitle)
                    .font(.title2)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .padding()
                
                SecureField("パスコードを入力", text: currentBinding)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .frame(maxWidth: 200)
                
                if step == .confirm && !passcode.isEmpty && !confirmPasscode.isEmpty && passcode != confirmPasscode {
                    Text("パスコードが一致しません")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("パスコード設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("次へ") {
                        handleNextStep()
                    }
                    .disabled(!canProceed)
                }
            }
        }
        .alert("エラー", isPresented: $showingError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private var stepTitle: String {
        switch step {
        case .initial:
            return "4桁のパスコードを設定してください"
        case .confirm:
            return "パスコードを再入力してください"
        case .complete:
            return "パスコードが設定されました"
        }
    }
    
    private var currentBinding: Binding<String> {
        switch step {
        case .initial, .complete:
            return $passcode
        case .confirm:
            return $confirmPasscode
        }
    }
    
    private var canProceed: Bool {
        switch step {
        case .initial:
            return passcode.count == 4
        case .confirm:
            return confirmPasscode.count == 4 && passcode == confirmPasscode
        case .complete:
            return true
        }
    }
    
    private func handleNextStep() {
        switch step {
        case .initial:
            step = .confirm
        case .confirm:
            if passcode == confirmPasscode {
                savePasscode()
                step = .complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    isPresented = false
                }
            } else {
                errorMessage = "パスコードが一致しません"
                showingError = true
            }
        case .complete:
            isPresented = false
        }
    }
    
    private func savePasscode() {
        // 実際の実装では、パスコードをキーチェーンに安全に保存する必要があります
        UserDefaults.standard.set(passcode, forKey: "userPasscode")
    }
}

struct DataExportView: View {
    var body: some View {
        VStack {
            Text("データエクスポート機能は準備中です")
                .padding()
        }
        .navigationTitle("データエクスポート")
    }
}

struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            Text("利用規約の内容がここに表示されます")
                .padding()
        }
        .navigationTitle("利用規約")
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            Text("プライバシーポリシーの内容がここに表示されます")
                .padding()
        }
        .navigationTitle("プライバシーポリシー")
    }
}

struct SupportView: View {
    var body: some View {
        List {
            Section("サポート") {
                Button("お問い合わせ") {
                    // メール送信機能
                }
                Button("使い方ガイド") {
                    // ガイド表示
                }
            }
        }
        .navigationTitle("サポート")
    }
}

#Preview {
    SettingsView()
}