#if DEBUG
import Foundation
import SwiftData

enum SampleData {
    static let markerID = UUID(uuid: (0xCC, 0xFF, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))

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
            for (index, activity) in activities.enumerated() {
                if (day + index) % 7 == 0 { continue }
                let wave = sin(Double(day * 3 + index) * 0.7)
                let typical = [1.6, 2.0, 0.75, 0.5][index]
                let hours = max(0.25, typical + wave * 0.4 + progress * 0.3)
                let date = min(base.addingTimeInterval(Double(9 + index * 2) * 3600), now)
                context.insert(Session(date: date, hours: (hours * 4).rounded() / 4,
                                       note: ["Problem sets and review", "Built a small feature",
                                              "Tactics and a rapid game", "A walk to reset"][index],
                                       activity: activity))
            }
            for (index, metric) in metrics.enumerated() {
                let wave = sin(Double(day) * 1.3 + Double(index))
                let value = index == 0 ? 78 + wave * 13 + progress * 4 : 28 + progress * 18 + wave * 6
                let date = min(base.addingTimeInterval(Double(8 + index * 12) * 3600), now)
                context.insert(MetricEntry(date: date, value: value.rounded(), metric: metric))
            }
        }
        try context.save()
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
