//
//  PracticeScheduleCalendarView.swift
//  TASUKI
//
//  参加予定の練習会をカレンダー形式で表示
//

import SwiftUI

struct PracticeScheduleCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: JoinedPracticesStore
    
    @State private var displayedMonth: Date = Date()
    @State private var selectedDay: Date?
    
    private let calendar = Calendar.current
    private let weekdaySymbols: [String] = {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "ja_JP")
        return cal.shortWeekdaySymbols
    }()
    
    private var monthTitle: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年M月"
        return f.string(from: displayedMonth)
    }
    
    private var daysInMonth: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let first = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) else {
            return []
        }
        let firstWeekday = calendar.component(.weekday, from: first)
        let offset = firstWeekday - 1
        var days: [Date?] = Array(repeating: nil, count: offset)
        for day in range {
            if let d = calendar.date(byAdding: .day, value: day - 1, to: first) {
                days.append(d)
            }
        }
        return days
    }
    
    private var practicesForSelected: [JoinedPracticeItem] {
        guard let day = selectedDay else { return store.items.filter { calendar.isDate($0.date, equalTo: displayedMonth, toGranularity: .month) }.sorted(by: { $0.date < $1.date }) }
        return store.items(on: day).sorted(by: { $0.date < $1.date })
    }
    
    private var sectionTitle: String {
        if let day = selectedDay {
            let f = DateFormatter()
            f.locale = Locale(identifier: "ja_JP")
            f.dateFormat = "M月d日(E)"
            return f.string(from: day)
        }
        return "今月の参加予定"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 月ナビ
                HStack {
                    Button {
                        if let prev = calendar.date(byAdding: .month, value: -1, to: displayedMonth) {
                            displayedMonth = prev
                            selectedDay = nil
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(hex: "0F1A2E"))
                    }
                    Spacer()
                    Text(monthTitle)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(hex: "0F1A2E"))
                    Spacer()
                    Button {
                        if let next = calendar.date(byAdding: .month, value: 1, to: displayedMonth) {
                            displayedMonth = next
                            selectedDay = nil
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(hex: "0F1A2E"))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                
                // 曜日ヘッダー
                HStack(spacing: 0) {
                    ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                        Text(symbol)
                            .frame(maxWidth: .infinity)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
                
                // カレンダーグリッド
                let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, dateOpt in
                        if let date = dateOpt {
                            let hasPractice = store.datesWithPractices(in: displayedMonth).contains(calendar.startOfDay(for: date))
                            let isSelected = selectedDay.map { calendar.isDate(date, inSameDayAs: $0) } ?? false
                            dayCell(date: date, hasPractice: hasPractice, isSelected: isSelected)
                        } else {
                            Color.clear
                                .frame(height: 36)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 20)
                
                Divider()
                
                // 選択日 or 今月の参加予定リスト
                VStack(alignment: .leading, spacing: 8) {
                    Text(sectionTitle)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "0F1A2E"))
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    
                    if practicesForSelected.isEmpty {
                        Text(selectedDay == nil ? "今月の参加予定はありません" : "この日の参加予定はありません")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                    } else {
                        List {
                            ForEach(practicesForSelected) { item in
                                practiceRow(item)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color.white)
            .navigationTitle("練習会スケジュール")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "2E5CFF"))
                }
            }
        }
    }
    
    private func dayCell(date: Date, hasPractice: Bool, isSelected: Bool) -> some View {
        let dayNum = calendar.component(.day, from: date)
        let isToday = calendar.isDateInToday(date)
        return Button {
            selectedDay = calendar.startOfDay(for: date)
        } label: {
            VStack(spacing: 4) {
                Text("\(dayNum)")
                    .font(.system(size: 16, weight: isToday ? .bold : .regular))
                    .foregroundColor(isSelected ? .white : (isToday ? Color(hex: "2E5CFF") : Color(hex: "0F1A2E")))
                if hasPractice {
                    Circle()
                        .fill(isSelected ? Color.white : Color(hex: "2E5CFF"))
                        .frame(width: 5, height: 5)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color(hex: "2E5CFF") : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func practiceRow(_ item: JoinedPracticeItem) -> some View {
        let timeStr: String = {
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            return f.string(from: item.date)
        }()
        return VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(hex: "0F1A2E"))
            HStack(spacing: 8) {
                Text(timeStr)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(item.location)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 8)
        .listRowBackground(Color.clear)
        .listRowSeparator(.visible)
    }
}

#if DEBUG
#Preview("カレンダー（サンプルあり）") {
    let store = JoinedPracticesStore()
    let cal = Calendar.current
    store.add(JoinedPracticeItem(id: "1", practiceId: "p1", title: "皇居ラン", location: "皇居", date: cal.date(byAdding: .day, value: 2, to: Date())!))
    store.add(JoinedPracticeItem(id: "2", practiceId: "p2", title: "代々木ジョグ", location: "代々木公園", date: cal.date(byAdding: .day, value: 5, to: Date())!))
    return PracticeScheduleCalendarView(store: store)
}
#endif
