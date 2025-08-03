//
//  AddCourseView.swift
//  At00
//
//  新規授業追加画面
//

import SwiftUI

struct AddCourseView: View {
    let dayOfWeek: Int
    let period: Int
    @ObservedObject var viewModel: AttendanceViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var courseName = ""
    @State private var totalClasses = 15
    @State private var maxAbsences = 5
    @State private var isFullYear = false
    @State private var selectedColorIndex = 0
    @State private var showingDuplicateNameAlert = false
    @State private var showingSlotOccupiedAlert = false
    @State private var slotOccupiedMessage = ""
    
    private let dayNames = ["", "月", "火", "水", "木", "金", "土", "日"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("授業情報") {
                    TextField("授業名", text: $courseName)
                    
                    HStack {
                        Text("曜日・時限")
                        Spacer()
                        Text("\(dayNames[dayOfWeek])曜日 \(period)限")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("授業設定") {
                    Stepper("総授業回数: \(totalClasses)回", value: $totalClasses, in: 1...30)
                    
                    Stepper("最大欠席可能: \(maxAbsences)回", value: $maxAbsences, in: 1...15)
                        .onChange(of: totalClasses) { _, newValue in
                            // 総授業回数が変更されたら、デフォルトの最大欠席可能回数を調整
                            maxAbsences = max(1, newValue / 3)
                        }
                    
                    Toggle("通年科目", isOn: $isFullYear)
                        .onChange(of: isFullYear) { _, newValue in
                            if newValue {
                                totalClasses = 30  // 通年科目は自動的に30回に設定
                                maxAbsences = 10
                            } else {
                                totalClasses = 15
                                maxAbsences = 5
                            }
                        }
                    
                    HStack {
                        Text("カラー")
                        Spacer()
                        ForEach(0..<8, id: \.self) { index in
                            Circle()
                                .fill(DesignSystem.getColor(for: index))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: selectedColorIndex == index ? 3 : 0)
                                )
                                .onTapGesture {
                                    selectedColorIndex = index
                                }
                        }
                    }
                }
                
                Section {
                    Text("※ 欠席可能回数は総授業回数の1/3が目安です")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("新規授業追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("追加") {
                        // 同名科目のチェック
                        if viewModel.hasCourseWithSameName(courseName) {
                            showingDuplicateNameAlert = true
                        } else {
                            // 授業追加を試行
                            let result = viewModel.addCourse(
                                name: courseName,
                                dayOfWeek: dayOfWeek,
                                period: period,
                                totalClasses: totalClasses,
                                isFullYear: isFullYear,
                                colorIndex: selectedColorIndex
                            )
                            
                            switch result {
                            case .success:
                                dismiss()
                            case .currentSlotOccupied:
                                slotOccupiedMessage = "現在の学期のこの時間帯には既に授業が登録されています。"
                                showingSlotOccupiedAlert = true
                            case .otherSemesterSlotOccupied:
                                let otherSemesterName = viewModel.currentSemesterType == .firstHalf ? "後期" : "前期"
                                slotOccupiedMessage = "通年科目として登録するには、\(otherSemesterName)の同じ時間帯も空いている必要があります。\n\n\(otherSemesterName)のこの時間帯には既に授業が登録されているため、通年科目として追加できません。"
                                showingSlotOccupiedAlert = true
                            case .bothSlotsOccupied:
                                slotOccupiedMessage = "前期・後期の両方でこの時間帯には既に授業が登録されています。"
                                showingSlotOccupiedAlert = true
                            }
                        }
                    }
                    .disabled(courseName.isEmpty)
                }
            }
            .alert("同名の授業が既に存在します", isPresented: $showingDuplicateNameAlert) {
                Button("既存授業一覧から選択") {
                    // 既存授業選択画面に遷移（CourseSelectionViewを使用）
                    dismiss()
                }
                Button("キャンセル") { }
            } message: {
                Text("「\(courseName)」という名前の授業は既に登録されています。\n\n同じ名前の授業を別の時間割に追加したい場合は、新規作成ではなく「既存の授業一覧から選択」してください。\n\nこうすることで、欠席記録が正しく同期され、どの時間割の授業で欠席しても同じカウントとして管理されます。")
            }
            .alert("時間割が重複しています", isPresented: $showingSlotOccupiedAlert) {
                Button("OK") { }
            } message: {
                Text(slotOccupiedMessage)
            }
        }
    }
}

#Preview {
    AddCourseView(
        dayOfWeek: 1,
        period: 1,
        viewModel: AttendanceViewModel(persistenceController: .preview)
    )
}