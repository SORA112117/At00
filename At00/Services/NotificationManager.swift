//
//  NotificationManager.swift
//  At00
//
//  通知管理サービス
//

import Foundation
import UserNotifications
import CoreData

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    private init() {}
    
    // MARK: - 通知権限管理
    
    /// 通知権限をリクエスト
    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            return granted
        } catch {
            print("通知権限のリクエストに失敗: \(error)")
            return false
        }
    }
    
    /// 現在の通知権限状態を取得
    func getAuthorizationStatus() async -> UNAuthorizationStatus {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }
    
    // MARK: - 欠席上限アラート通知
    
    /// 欠席回数が上限に近づいた際の通知を送信
    func scheduleAbsenceLimitWarning(courseName: String, currentAbsences: Int, maxAbsences: Int, remainingAbsences: Int) {
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled"),
              UserDefaults.standard.bool(forKey: "absentLimitNotification") else {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "⚠️ 欠席回数アラート"
        
        if remainingAbsences <= 0 {
            content.body = "【\(courseName)】単位取得が危険です！欠席回数が上限に達しました。"
            content.sound = .default
        } else if remainingAbsences <= 1 {
            content.body = "【\(courseName)】欠席回数があと\(remainingAbsences)回で上限です。注意してください。"
            content.sound = .default
        } else if remainingAbsences <= 2 {
            content.body = "【\(courseName)】欠席回数があと\(remainingAbsences)回で上限です。"
            content.sound = .default
        }
        
        content.categoryIdentifier = "ABSENCE_WARNING"
        content.userInfo = [
            "type": "absence_warning",
            "courseName": courseName,
            "currentAbsences": currentAbsences,
            "maxAbsences": maxAbsences,
            "remainingAbsences": remainingAbsences
        ]
        
        // 即座に通知を送信
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "absence_warning_\(courseName)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("欠席アラート通知の送信に失敗: \(error)")
            } else {
                print("欠席アラート通知を送信: \(courseName)")
            }
        }
    }
    
    // MARK: - リマインダー通知
    
    /// 定期的なリマインダー通知をスケジュール
    func scheduleReminderNotifications() {
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled"),
              UserDefaults.standard.bool(forKey: "reminderNotification") else {
            return
        }
        
        // 既存のリマインダー通知をキャンセル
        cancelReminderNotifications()
        
        let reminderTime = loadReminderTime()
        let frequency = UserDefaults.standard.string(forKey: "reminderFrequency") ?? "daily"
        
        let content = UNMutableNotificationContent()
        content.title = "📝 出席記録のリマインダー"
        content.body = "今日の授業の出席状況を記録しましたか？"
        content.sound = .default
        content.categoryIdentifier = "REMINDER"
        content.userInfo = ["type": "reminder"]
        
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: reminderTime)
        let minute = calendar.component(.minute, from: reminderTime)
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger: UNNotificationTrigger
        
        switch frequency {
        case "daily":
            trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        case "weekly":
            dateComponents.weekday = 2 // 月曜日
            trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        case "monthly":
            dateComponents.day = 1 // 毎月1日
            trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        default:
            trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        }
        
        let request = UNNotificationRequest(
            identifier: "reminder_notification",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("リマインダー通知のスケジュールに失敗: \(error)")
            } else {
                print("リマインダー通知をスケジュール: \(frequency)")
            }
        }
    }
    
    /// リマインダー通知をキャンセル
    func cancelReminderNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["reminder_notification"])
    }
    
    // MARK: - 授業開始前通知
    
    /// 授業開始前のリマインダー通知をスケジュール
    func scheduleClassReminders(for courses: [Course]) {
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled") else {
            return
        }
        
        // 既存の授業リマインダーをキャンセル
        cancelClassReminders()
        
        _ = Calendar.current
        _ = Date()
        
        for course in courses {
            guard let courseName = course.courseName else { continue }
            
            // 授業の曜日・時限から通知時刻を計算
            let dayOfWeek = Int(course.dayOfWeek) // 1=月曜日
            let period = Int(course.period) // 1=1限
            
            // 時限から開始時刻を計算（例：1限=9:00, 2限=10:50...）
            let startHour = getClassStartHour(period: period)
            let startMinute = getClassStartMinute(period: period)
            
            // 15分前に通知
            let notificationHour = startHour
            let notificationMinute = max(0, startMinute - 15)
            
            var dateComponents = DateComponents()
            dateComponents.weekday = dayOfWeek + 1 // Calendar.current の weekday は 1=日曜日
            dateComponents.hour = notificationHour
            dateComponents.minute = notificationMinute
            
            let content = UNMutableNotificationContent()
            content.title = "📚 授業開始のお知らせ"
            content.body = "【\(courseName)】の授業が15分後に開始します"
            content.sound = .default
            content.categoryIdentifier = "CLASS_REMINDER"
            content.userInfo = [
                "type": "class_reminder",
                "courseName": courseName,
                "dayOfWeek": dayOfWeek,
                "period": period
            ]
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: "class_reminder_\(courseName)_\(dayOfWeek)_\(period)",
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("授業リマインダー通知のスケジュールに失敗: \(error)")
                } else {
                    print("授業リマインダー通知をスケジュール: \(courseName)")
                }
            }
        }
    }
    
    /// 授業リマインダー通知をキャンセル
    func cancelClassReminders() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let classReminderIds = requests.filter { $0.identifier.hasPrefix("class_reminder_") }.map { $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: classReminderIds)
        }
    }
    
    // MARK: - ユーティリティメソッド
    
    /// リマインダー時刻を読み込み
    private func loadReminderTime() -> Date {
        let reminderTimeData = UserDefaults.standard.data(forKey: "reminderTime")
        if let data = reminderTimeData,
           let decoded = try? JSONDecoder().decode(Date.self, from: data) {
            return decoded
        } else {
            return Calendar.current.date(from: DateComponents(hour: 18, minute: 0)) ?? Date()
        }
    }
    
    /// 時限から授業開始時刻（時）を取得
    private func getClassStartHour(period: Int) -> Int {
        switch period {
        case 1: return 9   // 1限: 9:00-10:30
        case 2: return 10  // 2限: 10:50-12:20
        case 3: return 13  // 3限: 13:20-14:50
        case 4: return 15  // 4限: 15:10-16:40
        case 5: return 17  // 5限: 17:00-18:30
        default: return 9
        }
    }
    
    /// 時限から授業開始時刻（分）を取得
    private func getClassStartMinute(period: Int) -> Int {
        switch period {
        case 1: return 0   // 1限: 9:00
        case 2: return 50  // 2限: 10:50
        case 3: return 20  // 3限: 13:20
        case 4: return 10  // 4限: 15:10
        case 5: return 0   // 5限: 17:00
        default: return 0
        }
    }
    
    /// 全ての通知をキャンセル
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    
    /// 現在スケジュールされている通知一覧を取得（デバッグ用）
    func logScheduledNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            print("=== スケジュール済み通知一覧 ===")
            for request in requests {
                print("ID: \(request.identifier)")
                print("Title: \(request.content.title)")
                print("Body: \(request.content.body)")
                if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                    print("Trigger: \(trigger.dateComponents)")
                }
                print("---")
            }
            print("合計: \(requests.count)件")
        }
    }
}