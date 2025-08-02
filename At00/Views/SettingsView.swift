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
    @State private var showingResetConfirmation = false
    @State private var selectedSemesterForReset: Semester?
    
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
                    
                    NavigationLink("学期別時間割リセット") {
                        SemesterResetView(viewModel: viewModel)
                    }
                    .foregroundColor(.orange)
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

// MARK: - 学期別リセットビュー
struct SemesterResetView: View {
    @ObservedObject var viewModel: AttendanceViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedSemester: Semester?
    @State private var showingResetAlert = false
    
    var body: some View {
        List {
            Section {
                Text("リセットしたい学期を選択してください。選択した学期の時間割と欠席記録がすべて削除されます。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            }
            
            Section("学期一覧") {
                ForEach(viewModel.availableSemesters, id: \.semesterId) { semester in
                    SemesterSelectionRow(
                        semester: semester,
                        isSelected: selectedSemester?.semesterId == semester.semesterId,
                        viewModel: viewModel
                    ) {
                        selectedSemester = semester
                    }
                }
            }
        }
        .navigationTitle("学期別リセット")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("リセット") {
                    showingResetAlert = true
                }
                .foregroundColor(.red)
                .disabled(selectedSemester == nil)
            }
        }
        .alert("学期リセットの確認", isPresented: $showingResetAlert) {
            Button("リセット", role: .destructive) {
                if let semester = selectedSemester {
                    viewModel.resetSemesterTimetable(for: semester)
                    dismiss()
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            if let semester = selectedSemester {
                Text("\(semester.name ?? "")の時間割と欠席記録をすべて削除します。この操作は取り消せません。")
            }
        }
    }
}

struct SemesterSelectionRow: View {
    let semester: Semester
    let isSelected: Bool
    @ObservedObject var viewModel: AttendanceViewModel
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(semester.name ?? "")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text("開始: \(formatDate(semester.startDate))")
                        Text("終了: \(formatDate(semester.endDate))")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    Text("授業数: \(getCourseCount(for: semester))件")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "-" }
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
    
    private func getCourseCount(for semester: Semester) -> Int {
        let request: NSFetchRequest<Course> = Course.fetchRequest()
        request.predicate = NSPredicate(format: "semester == %@", semester)
        
        return (try? viewModel.managedObjectContext.count(for: request)) ?? 0
    }
}

#Preview {
    SettingsView()
}