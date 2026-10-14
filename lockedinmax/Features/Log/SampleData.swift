#if DEBUG
import Foundation
import SwiftData

enum SampleData {
    static let markerID = UUID(uuid: (0xCC, 0xFF, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
    private static let zeroDays: Set<Int> = [7, 23, 45]

    static func load(into context: ModelContext, now: Date = .now) throws {
        let marker = markerID
        let existing = FetchDescriptor<Activity>(predicate: #Predicate { $0.id == marker })
        guard try context.fetch(existing).isEmpty else { return }
        let activities = [
            Activity(name: "Math", colorHex: Theme.activityColorPresets[0], iconName: "function"),
            Activity(name: "Personal Projects", colorHex: Theme.activityColorPresets[1], iconName: "laptopcomputer"),
            Activity(name: "Chess", colorHex: Theme.activityColorPresets[2], iconName: "crown"),
            Activity(name: "Walks", colorHex: Theme.activityColorPresets[5], iconName: "figure.walk")
        ]
        activities[0].id = markerID
        let metrics = [Metric(name: "Sleep Score", unit: "pts"), Metric(name: "ZetaMac", unit: "pts")]
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let firstDay = calendar.date(byAdding: .day, value: -59, to: start) ?? start
        for activity in activities { activity.createdAt = firstDay; context.insert(activity) }
        for metric in metrics { metric.createdAt = firstDay; context.insert(metric) }

        for day in 0..<60 {
            guard let base = calendar.date(byAdding: .day, value: -day, to: start) else { continue }
            let progress = Double(59 - day) / 59

            if !zeroDays.contains(day) {
                for (index, activity) in activities.enumerated() {
                    // Chess intentionally has only two entries; other positions get a long, photo-less history.
                    guard index != 2 || day == 0 || day == 8 else { continue }
                    if index != 2, day > 1 && (day + index) % 7 == 0 { continue }
                    let hours = sessionHours(day: day, index: index, progress: progress)
                    let date = sessionDate(day: day, index: index, base: base, now: now, calendar: calendar)
                    context.insert(Session(date: date, hours: hours,
                                           note: ["Problem sets and review", "Built a small feature",
                                                  "Tactics and a rapid game", "A walk to reset"][index],
                                           activity: activity))
                }
            }

            for (index, metric) in metrics.enumerated() {
                let wave = sin(Double(day) * 1.3 + Double(index))
                let value = index == 0 ? 78 + wave * 13 + progress * 4 : 28 + progress * 18 + wave * 6
                let date = metricDate(day: day, index: index, base: base, now: now, calendar: calendar)
                context.insert(MetricEntry(date: date, value: value.rounded(), metric: metric))
            }
        }
        try context.save()
    }

    private static func sessionHours(day: Int, index: Int, progress: Double) -> Double {
        let wave = sin(Double(day * 3 + index) * 0.7)
        let typical = [1.6, 2.0, 0.75, 0.5][index]
        let hours = max(0.25, typical + wave * 0.35 + progress * 0.4)
        return (hours * 4).rounded() / 4
    }

    private static func sessionDate(day: Int, index: Int, base: Date, now: Date,
                                    calendar: Calendar) -> Date {
        let hour = 7 + ((day * 3 + index * 5) % 16)
        let minute = ((day * 17 + index * 11) % 4) * 15
        let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
        guard day == 0, date > now else { return date }
        let fallbackHour = calendar.component(.hour, from: now) < 7 ? 7 : 7 + index
        let fallback = calendar.date(bySettingHour: fallbackHour, minute: index * 15,
                                     second: 0, of: base) ?? base
        return min(fallback, now)
    }

    private static func metricDate(day: Int, index: Int, base: Date, now: Date,
                                   calendar: Calendar) -> Date {
        let hour = 7 + ((day * 5 + index * 7) % 16)
        let minute = ((day * 13 + index * 19) % 4) * 15
        let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
        guard day == 0, date > now else { return date }
        let earliest = calendar.startOfDay(for: now)
        return max(earliest, now.addingTimeInterval(-Double(index + 1) * 60))
    }

    static func clear(_ context: ModelContext) throws {
        for session in try context.fetch(FetchDescriptor<Session>()) { context.delete(session) }
        for entry in try context.fetch(FetchDescriptor<MetricEntry>()) { context.delete(entry) }
        for activity in try context.fetch(FetchDescriptor<Activity>()) { context.delete(activity) }
        for metric in try context.fetch(FetchDescriptor<Metric>()) { context.delete(metric) }
        try context.save()
    }
}
#endif
