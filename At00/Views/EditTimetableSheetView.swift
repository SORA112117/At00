//
//  EditTimetableSheetView.swift
//  At00
//
//  時間割シート編集画面
//

import SwiftUI
import CoreData

struct EditTimetableSheetView: View {
    @EnvironmentObject private var viewModel: AttendanceViewModel
    @Environment(\.dismiss) private var dismiss
    
    let semester: Semester
    @State private var sheetName = ""
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var showingDatePickers = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("シート情報") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("シート名称")
                            .font(.headline)
                        
                        TextField("シート名を入力", text: $sheetName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("学期")
                            .font(.headline)
                        
                        Text(getSemesterTypeName())
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    Toggle("期間を変更", isOn: $showingDatePickers)
                    
                    if showingDatePickers {
                        DatePicker("開始日", selection: $startDate, displayedComponents: .date)
                        DatePicker("終了日", selection: $endDate, displayedComponents: .date)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("現在の期間")
                                .font(.headline)
                            
                            HStack {
                                Text("開始:")
                                Text(formatDate(startDate))
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("終了:")
                                Text(formatDate(endDate))
                                    .foregroundColor(.secondary)
                            }
                            .font(.subheadline)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section("統計情報") {
                    HStack {
                        Text("登録授業数")
                        Spacer()
                        Text("\(getCourseCount())件")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("使用状況")
                        Spacer()
                        Text(semester.isActive ? "使用中" : "非使用")
                            .foregroundColor(semester.isActive ? .green : .secondary)
                    }
                }
                
                // ペア関係の表示
                if let pairedSemester = findPairedSemester() {
                    Section("関連する時間割シート") {
                        HStack {
                            Image(systemName: "link")
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ペアシート")
                                    .font(.headline)
                                Text(pairedSemester.name ?? "")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text("ペア")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("時間割シート編集")
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
                    }
                    .disabled(sheetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("エラー", isPresented: $showingErrorAlert) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
        .onAppear {
            sheetName = semester.name ?? ""
            startDate = semester.startDate ?? Date()
            endDate = semester.endDate ?? Date()
        }
    }
    
    // MARK: - Helper Methods
    
    /// 学期タイプ名を取得
    private func getSemesterTypeName() -> String {
        guard let semesterTypeString = semester.semesterType,
              let semesterType = SemesterType(rawValue: semesterTypeString) else {
            return "不明"
        }
        
        switch semesterType {
        case .firstHalf:
            return "前期"
        case .secondHalf:
            return "後期"
        }
    }
    
    /// 日付フォーマット
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "-" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: date)
    }
    
    /// 授業数を取得
    private func getCourseCount() -> Int {
        let request: NSFetchRequest<Course> = Course.fetchRequest()
        request.predicate = NSPredicate(format: "semester == %@", semester)
        return (try? viewModel.managedObjectContext.count(for: request)) ?? 0
    }
    
    /// ペアになる学期を検索
    private func findPairedSemester() -> Semester? {
        guard let semesterTypeString = semester.semesterType,
              let semesterType = SemesterType(rawValue: semesterTypeString),
              let startDate = semester.startDate else {
            return nil
        }
        
        let year = Calendar.current.component(.year, from: startDate)
        let pairedSemesterType: SemesterType = semesterType == .firstHalf ? .secondHalf : .firstHalf
        
        return viewModel.availableSemesters.first { otherSemester in
            guard let otherSemesterTypeString = otherSemester.semesterType,
                  let otherSemesterType = SemesterType(rawValue: otherSemesterTypeString),
                  otherSemesterType == pairedSemesterType,
                  let otherStartDate = otherSemester.startDate else {
                return false
            }
            
            let otherYear = Calendar.current.component(.year, from: otherStartDate)
            return otherYear == year
        }
    }
    
    /// 変更を保存
    private func saveChanges() {
        let trimmedName = sheetName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedName.isEmpty {
            errorMessage = "シート名を入力してください。"
            showingErrorAlert = true
            return
        }
        
        // 同じ名前のシートが他に存在するかチェック
        let isDuplicate = viewModel.availableSemesters.contains { otherSemester in
            otherSemester.semesterId != semester.semesterId && 
            otherSemester.name == trimmedName
        }
        
        if isDuplicate {
            errorMessage = "同じ名前の時間割シートが既に存在します。"
            showingErrorAlert = true
            return
        }
        
        // 名前と期間を更新
        semester.name = trimmedName
        if showingDatePickers {
            semester.startDate = startDate
            semester.endDate = endDate
            
            // ペアシートの期間も更新
            if let pairedSemester = findPairedSemester() {
                updatePairedSemesterDates(pairedSemester)
            }
        }
        
        // 保存
        do {
            try viewModel.managedObjectContext.save()
            
            // 通知を送信
            NotificationCenter.default.post(name: .courseDataDidChange, object: nil)
            
            dismiss()
        } catch {
            errorMessage = "時間割シートの更新に失敗しました: \(error.localizedDescription)"
            showingErrorAlert = true
        }
    }
    
    /// ペアシートの期間を更新
    private func updatePairedSemesterDates(_ pairedSemester: Semester) {
        guard let semesterTypeString = semester.semesterType,
              let semesterType = SemesterType(rawValue: semesterTypeString) else {
            return
        }
        
        if semesterType == .firstHalf {
            // 前期シートを編集した場合、後期シートの期間を前期に基づいて調整
            pairedSemester.startDate = Calendar.current.date(byAdding: .day, value: 1, to: endDate)
            
            // 後期の期間を前期の期間の長さに基づいて設定
            let firstHalfDuration = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
            if let pairStart = pairedSemester.startDate {
                pairedSemester.endDate = Calendar.current.date(byAdding: .day, value: firstHalfDuration, to: pairStart)
            }
        } else {
            // 後期シートを編集した場合、前期シートの期間を後期に基づいて調整
            pairedSemester.endDate = Calendar.current.date(byAdding: .day, value: -1, to: startDate)
            
            // 前期の期間を後期の期間の長さに基づいて設定
            let secondHalfDuration = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
            if let pairEnd = pairedSemester.endDate {
                pairedSemester.startDate = Calendar.current.date(byAdding: .day, value: -secondHalfDuration, to: pairEnd)
            }
        }
    }
}

#Preview {
    EditTimetableSheetView(semester: Semester())
}