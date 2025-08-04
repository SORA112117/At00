//
//  AddTimetableSheetView.swift
//  At00
//
//  時間割シート追加画面
//

import SwiftUI
import CoreData

struct AddTimetableSheetView: View {
    @EnvironmentObject private var viewModel: AttendanceViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var sheetName = ""
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedSemesterType: SemesterType = .firstHalf
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var showingDatePickers = false
    
    // 年度選択の範囲（現在年から前後3年）
    private var availableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((currentYear - 3)...(currentYear + 3))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("時間割シート情報") {
                    // シート名称入力
                    VStack(alignment: .leading, spacing: 8) {
                        Text("シート名称")
                            .font(.headline)
                        
                        TextField("例: 2025年度前期", text: $sheetName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding(.vertical, 4)
                    
                    // 年度選択
                    VStack(alignment: .leading, spacing: 8) {
                        Text("年度")
                            .font(.headline)
                        
                        Picker("年度", selection: $selectedYear) {
                            ForEach(availableYears, id: \.self) { year in
                                Text("\(year)年度").tag(year)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(height: 120)
                        .onChange(of: selectedYear) { _, _ in
                            // 年度が変更されたら期間を再計算
                            if !showingDatePickers {
                                startDate = getSemesterStartDate()
                                endDate = getSemesterEndDate()
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    
                    // 学期選択
                    VStack(alignment: .leading, spacing: 8) {
                        Text("学期")
                            .font(.headline)
                        
                        Picker("学期", selection: $selectedSemesterType) {
                            Text("前期").tag(SemesterType.firstHalf)
                            Text("後期").tag(SemesterType.secondHalf)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .onChange(of: selectedSemesterType) { _, _ in
                            // 学期が変更されたら期間を再計算
                            if !showingDatePickers {
                                startDate = getSemesterStartDate()
                                endDate = getSemesterEndDate()
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section("期間設定") {
                    Toggle("期間を手動で設定", isOn: $showingDatePickers)
                        .onChange(of: showingDatePickers) { _, isOn in
                            if !isOn {
                                // 自動設定に戻す
                                startDate = getSemesterStartDate()
                                endDate = getSemesterEndDate()
                            }
                        }
                    
                    if showingDatePickers {
                        DatePicker("開始日", selection: $startDate, displayedComponents: .date)
                        DatePicker("終了日", selection: $endDate, displayedComponents: .date)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("期間（自動設定）")
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
                
                // 既存シートとの関係性
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
            .navigationTitle("時間割シート追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("作成") {
                        createTimetableSheet()
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
            startDate = getSemesterStartDate()
            endDate = getSemesterEndDate()
        }
    }
    
    // MARK: - Helper Methods
    
    /// 学期の開始日を取得
    private func getSemesterStartDate() -> Date {
        let calendar = Calendar.current
        switch selectedSemesterType {
        case .firstHalf:
            return calendar.date(from: DateComponents(year: selectedYear, month: 4, day: 1)) ?? Date()
        case .secondHalf:
            return calendar.date(from: DateComponents(year: selectedYear, month: 10, day: 1)) ?? Date()
        }
    }
    
    /// 学期の終了日を取得
    private func getSemesterEndDate() -> Date {
        let calendar = Calendar.current
        switch selectedSemesterType {
        case .firstHalf:
            return calendar.date(from: DateComponents(year: selectedYear, month: 9, day: 30)) ?? Date()
        case .secondHalf:
            return calendar.date(from: DateComponents(year: selectedYear + 1, month: 3, day: 31)) ?? Date()
        }
    }
    
    /// 日付フォーマット
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: date)
    }
    
    /// ペアになる学期を検索
    private func findPairedSemester() -> Semester? {
        let pairedSemesterType: SemesterType = selectedSemesterType == .firstHalf ? .secondHalf : .firstHalf
        
        return viewModel.availableSemesters.first { semester in
            // 同じ年度で反対の学期
            guard let semesterTypeName = semester.semesterType,
                  let semesterType = SemesterType(rawValue: semesterTypeName),
                  semesterType == pairedSemesterType else {
                return false
            }
            
            // 年度が一致するかチェック
            let semesterYear = Calendar.current.component(.year, from: semester.startDate ?? Date())
            return semesterYear == selectedYear
        }
    }
    
    /// 同じシートが既に存在するかチェック
    private func isDuplicateSheet() -> Bool {
        return viewModel.availableSemesters.contains { semester in
            guard let semesterTypeName = semester.semesterType,
                  let semesterType = SemesterType(rawValue: semesterTypeName),
                  semesterType == selectedSemesterType else {
                return false
            }
            
            let semesterYear = Calendar.current.component(.year, from: semester.startDate ?? Date())
            return semesterYear == selectedYear
        }
    }
    
    /// 時間割シートを作成
    private func createTimetableSheet() {
        // 重複チェック
        if isDuplicateSheet() {
            let semesterName = selectedSemesterType == .firstHalf ? "前期" : "後期"
            errorMessage = "\(selectedYear)年度\(semesterName)の時間割シートは既に存在します。"
            showingErrorAlert = true
            return
        }
        
        // 新しい学期を作成
        let context = viewModel.managedObjectContext
        let newSemester = Semester(context: context)
        
        newSemester.semesterId = UUID()
        newSemester.name = sheetName.trimmingCharacters(in: .whitespacesAndNewlines)
        newSemester.semesterType = selectedSemesterType.rawValue
        newSemester.startDate = getSemesterStartDate()
        newSemester.endDate = getSemesterEndDate()
        newSemester.isActive = false // 作成時は非アクティブ
        newSemester.createdAt = Date()
        
        // 保存
        do {
            try context.save()
            
            // 利用可能学期リストを更新
            viewModel.setupSemesters()
            
            // 通知を送信
            NotificationCenter.default.post(name: .courseDataDidChange, object: nil)
            
            dismiss()
        } catch {
            errorMessage = "時間割シートの作成に失敗しました: \(error.localizedDescription)"
            showingErrorAlert = true
        }
    }
}

#Preview {
    AddTimetableSheetView()
}