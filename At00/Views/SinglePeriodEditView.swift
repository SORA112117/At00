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
            VStack(spacing: 20) {
                // コンパクトヘッダー
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.primary)
                            .frame(width: 50, height: 50)
                        
                        Text("\(period)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(.systemBackground))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(periods[period - 1])")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("\(formatTime(startTime)) - \(formatTime(endTime))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    if let duration = calculateDuration() {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(duration)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Text("分")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                )
                .padding(.horizontal)
                
                // スマートタイムピッカー
                VStack(spacing: 24) {
                    // 開始時刻
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.primary)
                                .font(.system(size: 16, weight: .medium))
                            Text("開始時刻")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            Spacer()
                            Text(formatTime(startTime))
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        
                        CustomTimePicker(
                            selection: $startTime,
                            minuteInterval: 5
                        )
                        .frame(height: 120)
                    }
                    
                    Divider()
                        .background(Color(.systemGray4))
                    
                    // 終了時刻
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.primary)
                                .font(.system(size: 16, weight: .medium))
                            Text("終了時刻")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            Spacer()
                            Text(formatTime(endTime))
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        
                        CustomTimePicker(
                            selection: $endTime,
                            minuteInterval: 5
                        )
                        .frame(height: 120)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: DesignSystem.adaptiveShadowColor, radius: 8, x: 0, y: 4)
                )
                .padding(.horizontal)
                
                Spacer()
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
        guard let semester = viewModel.currentSemester,
              let semesterId = semester.semesterId else { 
            print("Core Data整合性エラー: semester または semesterId が nil")
            return 
        }
        
        let request: NSFetchRequest<PeriodTime> = PeriodTime.fetchRequest()
        request.predicate = NSPredicate(
            format: "semesterId == %@ AND period == %d",
            semesterId as CVarArg,
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
        guard let semester = viewModel.currentSemester,
              let semesterId = semester.semesterId else {
            print("Core Data整合性エラー: semester または semesterId が nil")
            return
        }
        
        let context = viewModel.managedObjectContext
        
        // 既存のデータを検索
        let request: NSFetchRequest<PeriodTime> = PeriodTime.fetchRequest()
        request.predicate = NSPredicate(
            format: "semesterId == %@ AND period == %d",
            semesterId as CVarArg,
            period
        )
        request.fetchLimit = 1
        
        let periodTime: PeriodTime
        if let existing = try? context.fetch(request).first {
            periodTime = existing
        } else {
            periodTime = PeriodTime(context: context)
            periodTime.period = Int16(period)
            periodTime.semesterId = semesterId
        }
        
        periodTime.startTime = startTime
        periodTime.endTime = endTime
        
        try? context.save()
    }
}

struct CustomTimePicker: View {
    @Binding var selection: Date
    let minuteInterval: Int
    
    @State private var selectedHour: Int = 9
    @State private var selectedMinute: Int = 0
    @State private var isInitialized = false
    
    private let hours = Array(6...23) // 6:00 - 23:00
    private var minutes: [Int] {
        stride(from: 0, to: 60, by: minuteInterval).map { $0 }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // 時間ピッカー
            Picker("時", selection: $selectedHour) {
                ForEach(hours, id: \.self) { hour in
                    Text("\(hour)")
                        .font(.title2)
                        .fontWeight(.medium)
                        .tag(hour)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 80)
            .clipped()
            
            Text(":")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            // 分ピッカー
            Picker("分", selection: $selectedMinute) {
                ForEach(minutes, id: \.self) { minute in
                    Text(String(format: "%02d", minute))
                        .font(.title2)
                        .fontWeight(.medium)
                        .tag(minute)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 80)
            .clipped()
        }
        .onChange(of: selectedHour) { _, newHour in
            updateSelection()
        }
        .onChange(of: selectedMinute) { _, newMinute in
            updateSelection()
        }
        .onChange(of: selection) { _, newDate in
            if isInitialized {
                updateFromDate(newDate)
            }
        }
        .onAppear {
            if !isInitialized {
                updateFromDate(selection)
                isInitialized = true
            }
        }
    }
    
    private func updateSelection() {
        let calendar = Calendar.current
        let components = DateComponents(hour: selectedHour, minute: selectedMinute)
        if let newDate = calendar.date(from: components) {
            selection = newDate
        }
    }
    
    private func updateFromDate(_ date: Date) {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        
        // 最も近い5分刻みの値に調整
        let roundedMinute = (minute / minuteInterval) * minuteInterval
        
        // ピッカーの値を更新（初期化時は無限ループを避ける）
        selectedHour = hour
        selectedMinute = roundedMinute
        
        // 初期化時以外は選択値を更新
        if isInitialized {
            let components = DateComponents(hour: hour, minute: roundedMinute)
            if let adjustedDate = calendar.date(from: components) {
                DispatchQueue.main.async {
                    selection = adjustedDate
                }
            }
        }
    }
}

#Preview {
    SinglePeriodEditView(
        period: 1,
        viewModel: AttendanceViewModel(persistenceController: .preview)
    )
}