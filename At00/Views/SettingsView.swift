//
//  SettingsView.swift
//  At00
//
//  設定画面
//

import SwiftUI
import CoreData

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
                    
                    NavigationLink("通知設定") {
                        NotificationSettingsView()
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
        // Core Dataのすべてのデータを削除する処理
        // 実装時には適切なエラーハンドリングを追加
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

// 追加のView（簡単な実装）
struct NotificationSettingsView: View {
    var body: some View {
        List {
            Section("通知設定") {
                Toggle("プッシュ通知を有効にする", isOn: .constant(true))
                Toggle("欠席回数が上限に近づいたら通知", isOn: .constant(true))
            }
        }
        .navigationTitle("通知設定")
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