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
    @EnvironmentObject private var viewModel: AttendanceViewModel
    @State private var showingResetConfirmation = false
    @State private var selectedSemesterForReset: Semester?
    @Binding var shouldNavigateToSheetManagement: Bool
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
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
                    NavigationLink("時間割シート管理", value: "シート管理")
                    .foregroundColor(.blue)
                    
                    NavigationLink("学期別時間割リセット") {
                        SemesterResetView(viewModel: viewModel)
                    }
                    .foregroundColor(.orange)
                    
                    Button("アプリを初期状態にリセット") {
                        showingResetConfirmation = true
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
                    
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: String.self) { destination in
                if destination == "シート管理" {
                    TimetableSheetManagementView()
                }
            }
        }
        .onChange(of: shouldNavigateToSheetManagement) { _, newValue in
            if newValue {
                // シート管理ページに遷移
                navigationPath.append("シート管理")
                
                // フラグをリセット
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    shouldNavigateToSheetManagement = false
                }
            }
        }
        .alert("アプリを初期状態にリセット", isPresented: $showingResetConfirmation) {
            Button("リセット", role: .destructive) {
                viewModel.resetToDefaultSemester()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("すべてのデータ（授業、欠席記録、設定）が削除され、現在の期間に適した学期シートのみが作成されます。\n\nこの操作は取り消せません。")
        }
    }
}



// MARK: - 強化された設定ビュー群

struct NotificationSettingsView: View {
    @EnvironmentObject private var viewModel: AttendanceViewModel
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("absentLimitNotification") private var absentLimitNotification = true
    @AppStorage("reminderNotification") private var reminderNotification = false
    @AppStorage("reminderTime") private var reminderTimeData = Data()
    @AppStorage("reminderFrequency") private var reminderFrequency = "daily"
    
    @State private var reminderTime = Date()
    @State private var showingReminderSettings = false
    private let notificationManager = NotificationManager.shared
    
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
                            Task {
                                let granted = await viewModel.requestNotificationPermission()
                                if !granted {
                                    DispatchQueue.main.async {
                                        notificationsEnabled = false
                                    }
                                } else {
                                    // 通知が有効になったら設定を更新
                                    viewModel.updateReminderNotifications()
                                    viewModel.updateClassReminders()
                                }
                            }
                        } else {
                            // 通知が無効になったらすべてキャンセル
                            viewModel.cancelAllNotifications()
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
                            if newValue {
                                viewModel.updateReminderNotifications()
                            } else {
                                notificationManager.cancelReminderNotifications()
                            }
                        }
                    
                    if showingReminderSettings && reminderNotification {
                        DatePicker("通知時刻", selection: $reminderTime, displayedComponents: .hourAndMinute)
                            .onChange(of: reminderTime) { _, newValue in
                                saveReminderTime(newValue)
                                viewModel.updateReminderNotifications()
                            }
                        
                        Picker("頻度", selection: $reminderFrequency) {
                            ForEach(reminderFrequencies, id: \.0) { frequency, name in
                                Text(name).tag(frequency)
                            }
                        }
                        .onChange(of: reminderFrequency) { _, _ in
                            viewModel.updateReminderNotifications()
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

// MARK: - 時間割シート管理ビュー
struct TimetableSheetManagementView: View {
    @EnvironmentObject private var viewModel: AttendanceViewModel
    @State private var showingAddSheet = false
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var sheetToEdit: Semester?
    @State private var sheetToDelete: Semester?
    @State private var showingCannotDeleteLastSheetAlert = false
    
    var body: some View {
        List {
            Section {
                Text("時間割シートを追加・削除できます。前期と後期がペアになった時間割シートは、通年科目が自動的に同期されます。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            }
            
            Section("時間割シート一覧") {
                ForEach(viewModel.availableSemesters, id: \.semesterId) { semester in
                    TimetableSheetRow(
                        semester: semester,
                        onEdit: {
                            sheetToEdit = semester
                            showingEditSheet = true
                        },
                        onDelete: {
                            if viewModel.availableSemesters.count <= 1 {
                                showingCannotDeleteLastSheetAlert = true
                            } else {
                                sheetToDelete = semester
                                showingDeleteConfirmation = true
                            }
                        }
                    )
                }
            }
        }
        .navigationTitle("時間割シート管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("追加") {
                    showingAddSheet = true
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddTimetableSheetView()
        }
        .sheet(isPresented: $showingEditSheet) {
            if let semester = sheetToEdit {
                EditTimetableSheetView(semester: semester)
            }
        }
        .alert("時間割シート削除", isPresented: $showingDeleteConfirmation) {
            Button("削除", role: .destructive) {
                if let semester = sheetToDelete {
                    deleteTimetableSheet(semester)
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            if let semester = sheetToDelete {
                Text("\(semester.name ?? "")を削除しますか？\n\nこのシートの授業データと欠席記録がすべて削除されます。この操作は取り消せません。")
            }
        }
        .alert("削除できません", isPresented: $showingCannotDeleteLastSheetAlert) {
            Button("OK") {}
        } message: {
            Text("最後の時間割シートは削除できません。\nアプリには少なくとも1つの時間割シートが必要です。")
        }
    }
    
    private func deleteTimetableSheet(_ semester: Semester) {
        viewModel.resetSemesterTimetable(for: semester)
        
        // 学期自体も削除
        viewModel.managedObjectContext.delete(semester)
        viewModel.save()
        
        // 利用可能学期リストを更新
        viewModel.setupSemesters()
        
        sheetToDelete = nil
    }
}

// MARK: - 時間割シート行
struct TimetableSheetRow: View {
    let semester: Semester
    let onEdit: () -> Void
    let onDelete: () -> Void
    @EnvironmentObject private var viewModel: AttendanceViewModel
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(semester.name ?? "")
                    .font(.headline)
                
                HStack {
                    Text("開始: \(formatDate(semester.startDate))")
                    Text("終了: \(formatDate(semester.endDate))")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                Text("授業数: \(getCourseCount())件")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if semester.isActive {
                Text("使用中")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            // 編集ボタン
            Button("編集") {
                onEdit()
            }
            .font(.caption)
            .foregroundColor(.blue)
            .buttonStyle(PlainButtonStyle())
            
            // 削除ボタン
            Button("削除") {
                onDelete()
            }
            .font(.caption)
            .foregroundColor(.red)
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle()) // タップ領域を明確にする
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "-" }
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
    
    private func getCourseCount() -> Int {
        let request: NSFetchRequest<Course> = Course.fetchRequest()
        request.predicate = NSPredicate(format: "semester == %@", semester)
        return (try? viewModel.managedObjectContext.count(for: request)) ?? 0
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
                    
                    // リアルタイム反映のための通知送信
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        NotificationCenter.default.post(name: .courseDataDidChange, object: nil)
                        NotificationCenter.default.post(name: .attendanceDataDidChange, object: nil)
                        NotificationCenter.default.post(name: .statisticsDataDidChange, object: nil)
                    }
                    
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
    SettingsView(shouldNavigateToSheetManagement: .constant(false))
}