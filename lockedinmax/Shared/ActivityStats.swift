import Foundation

/// All-time statistics for one activity, calculated from its sessions without model-context access.
enum ActivityStats {
    struct Day: Equatable {
        let date: Date
        let hours: Double
    }

    struct Summary {
        let totalHours: Double
        let averageHoursPerActiveDay: Double
        let bestDay: Day?
        let streakDays: Int
    }

    static func calculate(sessions: [Session], now: Date, calendar: Calendar = .current) -> Summary {
        let hoursByDay = Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.date) }
            .mapValues { $0.reduce(0) { $0 + $1.hours } }
        let total = sessions.reduce(0) { $0 + $1.hours }
        let average = hoursByDay.isEmpty ? 0 : total / Double(hoursByDay.count)
        let best = hoursByDay.reduce(into: nil as Day?) { current, entry in
            let candidate = Day(date: entry.key, hours: entry.value)
            guard let existing = current else { current = candidate; return }
            if candidate.hours > existing.hours
                || (candidate.hours == existing.hours && candidate.date < existing.date) {
                current = candidate
            }
        }

        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        var day = hoursByDay[today] != nil ? today : yesterday
        var streak = 0
        while hoursByDay[day] != nil {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }

        return Summary(totalHours: total, averageHoursPerActiveDay: average,
                       bestDay: best, streakDays: streak)
    }

    static func dayLabel(_ date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "EEE dd MMM"
        return formatter.string(from: date).uppercased()
    }
}
