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
                        viewModel.addCourse(
                            name: courseName,
                            dayOfWeek: dayOfWeek,
                            period: period,
                            totalClasses: totalClasses
                        )
                        dismiss()
                    }
                    .disabled(courseName.isEmpty)
                }
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