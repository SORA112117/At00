//
//  PeriodTimeSettingsView.swift
//  At00
//
//  時限時間設定画面
//

import SwiftUI
import CoreData

struct PeriodTimeSettingsView: View {
    @StateObject private var viewModel = AttendanceViewModel()
    @State private var periodTimes: [PeriodTimeData] = []
    @State private var hasChanges = false
    @Environment(\.dismiss) private var dismiss
    
    struct PeriodTimeData: Identifiable {
        let id = UUID()
        let period: Int
        var startTime: Date
        var endTime: Date
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("各時限の開始・終了時刻を設定できます")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                
                Section("時限設定") {
                    ForEach(periodTimes.indices, id: \.self) { index in
                        PeriodTimeRow(
                            periodData: $periodTimes[index],
                            onTimeChanged: {
                                hasChanges = true
                            }
                        )
                    }
                }
            }
            .navigationTitle("時限時間設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        savePeriodTimes()
                        dismiss()
                    }
                    .disabled(!hasChanges)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadPeriodTimes()
            }
        }
    }
    
    private func loadPeriodTimes() {
        guard let semester = viewModel.currentSemester,
              let semesterId = semester.semesterId else {
            print("Core Data整合性エラー: semester または semesterId が nil")
            return
        }
        
        let request: NSFetchRequest<PeriodTime> = PeriodTime.fetchRequest()
        request.predicate = NSPredicate(format: "semesterId == %@", semesterId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PeriodTime.period, ascending: true)]
        
        let existingPeriodTimes = (try? viewModel.managedObjectContext.fetch(request)) ?? []
        
        // デフォルトの時限時間を設定（一般的な大学の授業時間）
        let defaultTimes = [
            (period: 1, start: createTime(hour: 9, minute: 0), end: createTime(hour: 10, minute: 30)),
            (period: 2, start: createTime(hour: 10, minute: 40), end: createTime(hour: 12, minute: 10)),
            (period: 3, start: createTime(hour: 13, minute: 0), end: createTime(hour: 14, minute: 30)),
            (period: 4, start: createTime(hour: 14, minute: 40), end: createTime(hour: 16, minute: 10)),
            (period: 5, start: createTime(hour: 16, minute: 20), end: createTime(hour: 17, minute: 50))
        ]
        
        periodTimes = defaultTimes.map { defaultTime in
            if let existing = existingPeriodTimes.first(where: { $0.period == defaultTime.period }) {
                return PeriodTimeData(
                    period: Int(existing.period),
                    startTime: existing.startTime ?? defaultTime.start,
                    endTime: existing.endTime ?? defaultTime.end
                )
            } else {
                return PeriodTimeData(
                    period: defaultTime.period,
                    startTime: defaultTime.start,
                    endTime: defaultTime.end
                )
            }
        }
    }
    
    private func createTime(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        let components = DateComponents(hour: hour, minute: minute)
        return calendar.date(from: components) ?? Date()
    }
    
    private func savePeriodTimes() {
        guard let semester = viewModel.currentSemester,
              let semesterId = semester.semesterId else {
            print("Core Data整合性エラー: semester または semesterId が nil")
            return
        }
        
        let context = viewModel.managedObjectContext
        
        // 既存の時限時間設定を削除
        let request: NSFetchRequest<PeriodTime> = PeriodTime.fetchRequest()
        request.predicate = NSPredicate(format: "semesterId == %@", semesterId as CVarArg)
        let existingPeriodTimes = (try? context.fetch(request)) ?? []
        existingPeriodTimes.forEach { context.delete($0) }
        
        // 新しい設定を保存
        for periodData in periodTimes {
            let periodTime = PeriodTime(context: context)
            periodTime.period = Int16(periodData.period)
            periodTime.startTime = periodData.startTime
            periodTime.endTime = periodData.endTime
            periodTime.semesterId = semesterId
        }
        
        try? context.save()
        hasChanges = false
    }
}

struct PeriodTimeRow: View {
    @Binding var periodData: PeriodTimeSettingsView.PeriodTimeData
    let onTimeChanged: () -> Void
    @State private var showingTimePicker = false
    
    var body: some View {
        Button {
            showingTimePicker = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(periodData.period)限")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(timeRangeText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "clock")
                    .foregroundColor(.blue)
                    .font(.title2)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingTimePicker) {
            PeriodTimeEditView(
                periodData: $periodData,
                onTimeChanged: onTimeChanged
            )
        }
    }
    
    private var timeRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let startText = formatter.string(from: periodData.startTime)
        let endText = formatter.string(from: periodData.endTime)
        return "\(startText) - \(endText)"
    }
}

struct PeriodTimeEditView: View {
    @Binding var periodData: PeriodTimeSettingsView.PeriodTimeData
    let onTimeChanged: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var tempStartTime: Date
    @State private var tempEndTime: Date
    
    init(periodData: Binding<PeriodTimeSettingsView.PeriodTimeData>, onTimeChanged: @escaping () -> Void) {
        self._periodData = periodData
        self.onTimeChanged = onTimeChanged
        self._tempStartTime = State(initialValue: periodData.wrappedValue.startTime)
        self._tempEndTime = State(initialValue: periodData.wrappedValue.endTime)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // ヘッダー情報
                VStack(spacing: 8) {
                    Text("\(periodData.period)限")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("授業時間を設定してください")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                // 時間設定
                VStack(spacing: 32) {
                    // 開始時刻
                    VStack(spacing: 16) {
                        HStack {
                            Text("開始時刻")
                                .font(.headline)
                            Spacer()
                            Text(formatTime(tempStartTime))
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                        
                        DatePicker(
                            "開始時刻",
                            selection: $tempStartTime,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(height: 120)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    
                    // 終了時刻
                    VStack(spacing: 16) {
                        HStack {
                            Text("終了時刻")
                                .font(.headline)
                            Spacer()
                            Text(formatTime(tempEndTime))
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                        
                        DatePicker(
                            "終了時刻",
                            selection: $tempEndTime,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(height: 120)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                }
                
                Spacer()
                
                // 時間範囲表示
                HStack {
                    Text("授業時間:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(formatTime(tempStartTime)) - \(formatTime(tempEndTime))")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: DesignSystem.adaptiveShadowColor, radius: 4, x: 0, y: 2)
            }
            .padding()
            .navigationTitle("時間設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        periodData.startTime = tempStartTime
                        periodData.endTime = tempEndTime
                        onTimeChanged()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(tempStartTime >= tempEndTime)
                }
            }
        }
    }
    
    private func formatTime(_ time: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: time)
    }
}

#Preview {
    PeriodTimeSettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}