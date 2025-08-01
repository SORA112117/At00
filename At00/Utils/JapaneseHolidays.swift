//
//  JapaneseHolidays.swift
//  At00
//
//  日本の祝日計算ユーティリティ
//

import Foundation

class JapaneseHolidays {
    static let shared = JapaneseHolidays()
    
    private init() {}
    
    // 指定された年の祝日一覧を取得
    func getHolidays(for year: Int) -> Set<Date> {
        var holidays = Set<Date>()
        
        // 固定祝日
        holidays.insert(date(year: year, month: 1, day: 1)!)   // 元日
        holidays.insert(date(year: year, month: 2, day: 11)!)  // 建国記念の日
        holidays.insert(date(year: year, month: 2, day: 23)!)  // 天皇誕生日
        holidays.insert(date(year: year, month: 4, day: 29)!)  // 昭和の日
        holidays.insert(date(year: year, month: 5, day: 3)!)   // 憲法記念日
        holidays.insert(date(year: year, month: 5, day: 4)!)   // みどりの日
        holidays.insert(date(year: year, month: 5, day: 5)!)   // こどもの日
        holidays.insert(date(year: year, month: 8, day: 11)!)  // 山の日
        holidays.insert(date(year: year, month: 11, day: 3)!)  // 文化の日
        holidays.insert(date(year: year, month: 11, day: 23)!) // 勤労感謝の日
        
        // 移動祝日
        if let comingOfAge = comingOfAgeDay(year: year) {
            holidays.insert(comingOfAge) // 成人の日
        }
        
        if let marineDay = marineDay(year: year) {
            holidays.insert(marineDay) // 海の日
        }
        
        if let respectForAged = respectForAgedDay(year: year) {
            holidays.insert(respectForAged) // 敬老の日
        }
        
        if let sportsDay = sportsDay(year: year) {
            holidays.insert(sportsDay) // スポーツの日
        }
        
        // 春分の日・秋分の日
        if let vernalEquinox = vernalEquinox(year: year) {
            holidays.insert(vernalEquinox)
        }
        
        if let autumnalEquinox = autumnalEquinox(year: year) {
            holidays.insert(autumnalEquinox)
        }
        
        // 振替休日の処理
        let substituteDays = getSubstituteHolidays(holidays: holidays, year: year)
        holidays.formUnion(substituteDays)
        
        return holidays
    }
    
    // 指定された日付が祝日かどうかを判定
    func isHoliday(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let holidays = getHolidays(for: year)
        
        return holidays.contains { holiday in
            calendar.isDate(date, inSameDayAs: holiday)
        }
    }
    
    // MARK: - Private Methods
    
    private func date(year: Int, month: Int, day: Int) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)
    }
    
    // 成人の日（1月第2月曜日）
    private func comingOfAgeDay(year: Int) -> Date? {
        return nthWeekday(year: year, month: 1, weekday: 2, n: 2)
    }
    
    // 海の日（7月第3月曜日）
    private func marineDay(year: Int) -> Date? {
        return nthWeekday(year: year, month: 7, weekday: 2, n: 3)
    }
    
    // 敬老の日（9月第3月曜日）
    private func respectForAgedDay(year: Int) -> Date? {
        return nthWeekday(year: year, month: 9, weekday: 2, n: 3)
    }
    
    // スポーツの日（10月第2月曜日）
    private func sportsDay(year: Int) -> Date? {
        return nthWeekday(year: year, month: 10, weekday: 2, n: 2)
    }
    
    // 指定月のn番目の指定曜日の日付を取得
    private func nthWeekday(year: Int, month: Int, weekday: Int, n: Int) -> Date? {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        
        guard let firstDay = calendar.date(from: components) else { return nil }
        
        components.weekday = weekday
        components.weekdayOrdinal = n
        
        return calendar.nextDate(after: firstDay.addingTimeInterval(-1), matching: components, matchingPolicy: .nextTime)
    }
    
    // 春分の日（概算）
    private func vernalEquinox(year: Int) -> Date? {
        let day = Int(20.8431 + 0.242194 * Double(year - 1851) - Double((year - 1851) / 4))
        return date(year: year, month: 3, day: day)
    }
    
    // 秋分の日（概算）
    private func autumnalEquinox(year: Int) -> Date? {
        let day = Int(23.2488 + 0.242194 * Double(year - 1851) - Double((year - 1851) / 4))
        return date(year: year, month: 9, day: day)
    }
    
    // 振替休日の取得
    private func getSubstituteHolidays(holidays: Set<Date>, year: Int) -> Set<Date> {
        var substitutes = Set<Date>()
        let calendar = Calendar.current
        
        for holiday in holidays {
            // 日曜日の祝日の場合、翌平日を振替休日とする
            if calendar.component(.weekday, from: holiday) == 1 {
                var nextDay = calendar.date(byAdding: .day, value: 1, to: holiday)!
                
                while holidays.contains(nextDay) || calendar.component(.weekday, from: nextDay) == 1 {
                    nextDay = calendar.date(byAdding: .day, value: 1, to: nextDay)!
                }
                
                substitutes.insert(nextDay)
            }
        }
        
        return substitutes
    }
}