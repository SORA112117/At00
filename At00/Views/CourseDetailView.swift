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
                VStack(spacing: 24) {
                    // ヘッダーカード（授業名とカラー）
                    VStack(spacing: 16) {
                        HStack {
                            Rectangle()
                                .fill(DesignSystem.getColor(for: Int(course.colorIndex)))
                                .frame(width: 6, height: 60)
                                .cornerRadius(3)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(course.courseName ?? "")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text("\(dayName)曜日 \(course.period)限")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        // 出席状況の大きな表示
                        HStack(spacing: 20) {
                            VStack {
                                Text("\(viewModel.getAbsenceCount(for: course))")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(viewModel.getStatusColor(for: course))
                                
                                Text("欠席回数")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack {
                                Text("\(viewModel.getRemainingAbsences(for: course))")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(.green)
                                
                                Text("残り可能")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical)
                    }
                    .padding()
                    .cardStyle()
                    
                    // プログレスバー
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("出席状況")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(course.maxAbsences) - viewModel.getAbsenceCount(for: course))/\(course.maxAbsences)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        ProgressView(value: Double(viewModel.getAbsenceCount(for: course)), 
                                   total: Double(course.maxAbsences))
                            .progressViewStyle(LinearProgressViewStyle(tint: viewModel.getStatusColor(for: course)))
                            .scaleEffect(x: 1, y: 3, anchor: .center)
                    }
                    .padding()
                    .cardStyle()
                    
                    // アクションボタン
                    VStack(spacing: 12) {
                        // 欠席記録ボタン
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                viewModel.recordAbsence(for: course)
                            }
                            // ハプティックフィードバック
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                dismiss()
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("欠席を記録")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("タップで即座に記録")
                                        .font(.caption)
                                        .opacity(0.8)
                                }
                                Spacer()
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.red, .red.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                        }
                        
                        HStack(spacing: 12) {
                            // 詳細記録ボタン
                            Button(action: {
                                showingRecordDetail = true
                            }) {
                                HStack {
                                    Image(systemName: "pencil")
                                    Text("詳細記録")
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.blue)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                            }
                            
                            // 取り消しボタン
                            Button(action: {
                                withAnimation(.spring()) {
                                    viewModel.undoLastRecord(for: course)
                                }
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.uturn.backward")
                                    Text("取り消し")
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.orange)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
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