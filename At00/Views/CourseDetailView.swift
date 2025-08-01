//
//  CourseDetailView.swift
//  At00
//
//  授業詳細画面
//

import SwiftUI

struct CourseDetailView: View {
    let course: Course
    @ObservedObject var viewModel: AttendanceViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingRecordDetail = false
    @State private var selectedRecordType = AttendanceType.absent
    @State private var recordMemo = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 授業基本情報
                    VStack(alignment: .leading, spacing: 12) {
                        Text("授業情報")
                            .font(.headline)
                        
                        InfoRow(title: "授業名", value: course.courseName ?? "")
                        InfoRow(title: "曜日・時限", value: "\(dayName)曜日 \(course.period)限")
                        InfoRow(title: "総授業回数", value: "\(course.totalClasses)回")
                        InfoRow(title: "最大欠席可能回数", value: "\(course.maxAbsences)回")
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // 出席状況サマリー
                    VStack(alignment: .leading, spacing: 12) {
                        Text("出席状況")
                            .font(.headline)
                        
                        HStack {
                            StatusCard(
                                title: "現在の欠席回数",
                                value: "\(viewModel.getAbsenceCount(for: course))",
                                color: viewModel.getStatusColor(for: course)
                            )
                            
                            StatusCard(
                                title: "残り欠席可能",
                                value: "\(viewModel.getRemainingAbsences(for: course))",
                                color: viewModel.getStatusColor(for: course)
                            )
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // アクションボタン
                    VStack(spacing: 16) {
                        // 欠席記録ボタン
                        Button(action: {
                            viewModel.recordAbsence(for: course)
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "minus.circle.fill")
                                Text("欠席を記録")
                            }
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color.red)
                            .cornerRadius(12)
                        }
                        
                        // 詳細記録ボタン
                        Button(action: {
                            showingRecordDetail = true
                        }) {
                            HStack {
                                Image(systemName: "pencil.circle.fill")
                                Text("詳細記録")
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                        
                        // 取り消しボタン
                        Button(action: {
                            viewModel.undoLastRecord(for: course)
                        }) {
                            HStack {
                                Image(systemName: "arrow.uturn.backward.circle.fill")
                                Text("最後の記録を取り消し")
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.orange)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle(course.courseName ?? "授業詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingRecordDetail) {
                RecordDetailView(
                    course: course,
                    viewModel: viewModel,
                    selectedType: $selectedRecordType,
                    memo: $recordMemo
                )
            }
        }
    }
    
    private var dayName: String {
        let days = ["", "月", "火", "水", "木", "金", "土", "日"]
        let dayIndex = Int(course.dayOfWeek)
        return dayIndex > 0 && dayIndex < days.count ? days[dayIndex] : ""
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct StatusCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
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
    
    return CourseDetailView(course: course, viewModel: AttendanceViewModel(persistenceController: .preview))
}