//
//  RecordDetailView.swift
//  At00
//
//  詳細記録画面（種別選択・メモ入力）
//

import SwiftUI

struct RecordDetailView: View {
    let course: Course
    @ObservedObject var viewModel: AttendanceViewModel
    @Binding var selectedType: AttendanceType
    @Binding var memo: String
    @Environment(\.dismiss) private var dismiss
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 24) {
                // 授業情報
                VStack(alignment: .leading, spacing: 8) {
                    Text(course.courseName ?? "")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("\(dayName)曜日 \(course.period)限")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // 記録種別選択
                VStack(alignment: .leading, spacing: 16) {
                    Text("記録種別")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        ForEach(AttendanceType.allCases, id: \.self) { type in
                            Button(action: {
                                selectedType = type
                            }) {
                                VStack(spacing: 8) {
                                    Text(type.emoji)
                                        .font(.system(size: 32))
                                    
                                    Text(type.displayName)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(selectedType == type ? .white : .primary)
                                }
                                .frame(maxWidth: .infinity, minHeight: 80)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedType == type ? Color.blue : Color(.systemGray6))
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                // メモ入力
                VStack(alignment: .leading, spacing: 12) {
                    Text("メモ（任意）")
                        .font(.headline)
                    
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                            .frame(minHeight: 80)
                        
                        if memo.isEmpty {
                            Text("メモを入力してください")
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 12)
                        }
                        
                        TextEditor(text: $memo)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 8)
                            .background(Color.clear)
                            .frame(minHeight: 80)
                            .scrollContentBackground(.hidden)
                    }
                }
                
                Spacer()
                
                // 記録ボタン
                Button(action: {
                    let result = viewModel.recordAbsence(for: course, type: selectedType, memo: memo)
                    
                    switch result {
                    case .success:
                        dismiss()
                    case .alreadyRecorded:
                        errorMessage = "今日の欠席は既に記録されています。"
                        showingErrorAlert = true
                    case .dailyLimitReached:
                        errorMessage = "今日はすべてのコマで欠席記録済みです。"
                        showingErrorAlert = true
                    case .outsideSemesterPeriod:
                        errorMessage = "今日の日付は学期期間外です。\n欠席記録は学期期間内のみ可能です。"
                        showingErrorAlert = true
                    }
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("記録する")
                    }
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
            }
            .padding()
            .navigationTitle("詳細記録")
            .navigationBarTitleDisplayMode(.inline)
            .alert("エラー", isPresented: $showingErrorAlert) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var dayName: String {
        let days = ["", "月", "火", "水", "木", "金", "土", "日"]
        let dayIndex = Int(course.dayOfWeek)
        return dayIndex > 0 && dayIndex < days.count ? days[dayIndex] : ""
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let course = Course(context: context)
    course.courseName = "プログラミング基礎"
    course.dayOfWeek = 1
    course.period = 1
    
    return RecordDetailView(
        course: course,
        viewModel: AttendanceViewModel(persistenceController: .preview),
        selectedType: .constant(.absent),
        memo: .constant("")
    )
}