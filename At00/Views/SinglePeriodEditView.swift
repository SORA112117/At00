//
//  SinglePeriodEditView.swift
//  At00
//
//  個別時限編集画面
//

import SwiftUI
import CoreData

struct SinglePeriodEditView: View {
    let period: Int
    @ObservedObject var viewModel: AttendanceViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date()
    @State private var hasLoaded = false
    
    private let periods = ["1限", "2限", "3限", "4限", "5限"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // ヘッダー
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 80, height: 80)
                        
                        Text("\(period)")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.blue)
                    }
                    
                    Text("\(periods[period - 1])の時間設定")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                .padding(.top, 20)
                
                // 時間設定セクション
                VStack(spacing: 24) {
                    // 開始時刻
                    VStack(alignment: .leading, spacing: 12) {
                        Label("開始時刻", systemImage: "clock")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack {
                            Spacer()
                            
                            DatePicker(
                                "",
                                selection: $startTime,
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(width: 200, height: 100)
                            
                            Spacer()
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemGray6))
                        )
                    }
                    
                    // 矢印
                    Image(systemName: "arrow.down")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    // 終了時刻
                    VStack(alignment: .leading, spacing: 12) {
                        Label("終了時刻", systemImage: "clock.badge.checkmark")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack {
                            Spacer()
                            
                            DatePicker(
                                "",
                                selection: $endTime,
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(width: 200, height: 100)
                            
                            Spacer()
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemGray6))
                        )
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // 授業時間表示
                VStack(spacing: 8) {
                    Text("授業時間")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(formatTime(startTime)) - \(formatTime(endTime))")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if let duration = calculateDuration() {
                        Text("(\(duration)分)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                )
                .padding(.horizontal)
            }
            .navigationTitle("\(periods[period - 1])編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        savePeriodTime()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(startTime >= endTime)
                }
            }
            .onAppear {
                if !hasLoaded {
                    loadPeriodTime()
                    hasLoaded = true
                }
            }
        }
    }
    
    private func formatTime(_ time: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: time)
    }
    
    private func calculateDuration() -> Int? {
        let duration = endTime.timeIntervalSince(startTime)
        return duration > 0 ? Int(duration / 60) : nil
    }
    
    private func loadPeriodTime() {
        guard let semester = viewModel.currentSemester else { return }
        
        let request: NSFetchRequest<PeriodTime> = PeriodTime.fetchRequest()
        request.predicate = NSPredicate(
            format: "semesterId == %@ AND period == %d",
            semester.semesterId! as CVarArg,
            period
        )
        request.fetchLimit = 1
        
        if let periodTime = try? viewModel.managedObjectContext.fetch(request).first {
            startTime = periodTime.startTime ?? createDefaultTime(for: period, isStart: true)
            endTime = periodTime.endTime ?? createDefaultTime(for: period, isStart: false)
        } else {
            // デフォルト時間を設定
            startTime = createDefaultTime(for: period, isStart: true)
            endTime = createDefaultTime(for: period, isStart: false)
        }
    }
    
    private func createDefaultTime(for period: Int, isStart: Bool) -> Date {
        let calendar = Calendar.current
        let defaultTimes = [
            1: (start: (9, 0), end: (10, 30)),
            2: (start: (10, 40), end: (12, 10)),
            3: (start: (13, 0), end: (14, 30)),
            4: (start: (14, 40), end: (16, 10)),
            5: (start: (16, 20), end: (17, 50))
        ]
        
        let time = defaultTimes[period] ?? (start: (9, 0), end: (10, 30))
        let components = isStart ?
            DateComponents(hour: time.start.0, minute: time.start.1) :
            DateComponents(hour: time.end.0, minute: time.end.1)
        
        return calendar.date(from: components) ?? Date()
    }
    
    private func savePeriodTime() {
        guard let semester = viewModel.currentSemester else { return }
        
        let context = viewModel.managedObjectContext
        
        // 既存のデータを検索
        let request: NSFetchRequest<PeriodTime> = PeriodTime.fetchRequest()
        request.predicate = NSPredicate(
            format: "semesterId == %@ AND period == %d",
            semester.semesterId! as CVarArg,
            period
        )
        request.fetchLimit = 1
        
        let periodTime: PeriodTime
        if let existing = try? context.fetch(request).first {
            periodTime = existing
        } else {
            periodTime = PeriodTime(context: context)
            periodTime.period = Int16(period)
            periodTime.semesterId = semester.semesterId!
        }
        
        periodTime.startTime = startTime
        periodTime.endTime = endTime
        
        try? context.save()
    }
}

#Preview {
    SinglePeriodEditView(
        period: 1,
        viewModel: AttendanceViewModel(persistenceController: .preview)
    )
}