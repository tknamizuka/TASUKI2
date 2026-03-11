//
//  JoinedPracticesStore.swift
//  TASUKI
//
//  参加予定の練習会を保持し、HomeView のカレンダー・バッジで表示するためのストア
//

import Foundation
import Combine

/// 参加予定の練習会 1 件（カレンダー表示用）
struct JoinedPracticeItem: Identifiable {
    let id: String
    let practiceId: String
    let title: String
    let location: String
    let date: Date
    
    var dateOnly: Date {
        Calendar.current.startOfDay(for: date)
    }
}

/// 参加予定の練習会一覧を管理。参加/キャンセル時に PracticeDetailView から更新される
final class JoinedPracticesStore: ObservableObject {
    @Published private(set) var items: [JoinedPracticeItem] = []
    
    var scheduledCount: Int { items.count }
    
    /// 参加時に呼ぶ
    func add(_ item: JoinedPracticeItem) {
        guard !items.contains(where: { $0.practiceId == item.practiceId }) else { return }
        items.append(item)
    }
    
    /// キャンセル時に呼ぶ
    func remove(practiceId: String) {
        items.removeAll { $0.practiceId == practiceId }
    }
    
    /// 指定日の参加予定一覧
    func items(on date: Date) -> [JoinedPracticeItem] {
        let day = Calendar.current.startOfDay(for: date)
        return items.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }
    
    /// 指定月に参加予定がある日付の集合
    func datesWithPractices(in month: Date) -> Set<Date> {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: month))!
        let range = cal.range(of: .day, in: .month, for: start)!
        var set = Set<Date>()
        for item in items {
            let d = cal.startOfDay(for: item.date)
            if cal.isDate(d, equalTo: start, toGranularity: .month) {
                set.insert(d)
            }
        }
        return set
    }
}
