#if DEBUG
import Foundation
import SwiftData
import SwiftUI
#if os(iOS)
import UIKit
#endif

enum SampleData {
    private static let zeroDays: Set<Int> = [7, 23, 45]
    private static let sampleSeed: UInt64 = 0x4C4F434B4544494E

    static func load(into context: ModelContext, replacingExisting: Bool = false,
                     now: Date = .now) throws -> SampleLoadTimings {
        let totalStart = ProcessInfo.processInfo.systemUptime
        let generationStart = totalStart
        let generated = try makeSampleData(now: now)
        let generationMilliseconds = (ProcessInfo.processInfo.systemUptime - generationStart) * 1_000
        let insertionStart = ProcessInfo.processInfo.systemUptime
        let oldSessions = try context.fetch(FetchDescriptor<Session>())
        let oldEntries = try context.fetch(FetchDescriptor<MetricEntry>())
        let oldActivities = try context.fetch(FetchDescriptor<Activity>())
        let oldMetrics = try context.fetch(FetchDescriptor<Metric>())

        if replacingExisting {
            oldSessions.forEach(context.delete)
            oldEntries.forEach(context.delete)
            oldActivities.forEach(context.delete)
            oldMetrics.forEach(context.delete)
        } else {
            assignUniqueNames(to: generated.activities, avoiding: oldActivities.map(\.name))
            assignUniqueNames(to: generated.metrics, avoiding: oldMetrics.map(\.name))
        }

        let activities = generated.activities
        let metrics = generated.metrics
        let sessions = generated.sessions
        let entries = generated.entries
        let firstDay = generated.firstDay
        guard sessions.count == 171, activities.count == 7, metrics.count == 3, entries.count == 75,
              sessions.allSatisfy({ $0.hours.isFinite && (0.0...24.0).contains($0.hours) }) else {
            throw SampleDataError.invalidGeneratedData
        }
        for activity in activities { activity.createdAt = firstDay; context.insert(activity) }
        for metric in metrics { metric.createdAt = firstDay; context.insert(metric) }
        sessions.forEach(context.insert)
        entries.forEach(context.insert)
        let insertionMilliseconds = (ProcessInfo.processInfo.systemUptime - insertionStart) * 1_000
        let saveStart = ProcessInfo.processInfo.systemUptime
        try context.save()
        let saveMilliseconds = (ProcessInfo.processInfo.systemUptime - saveStart) * 1_000
        return SampleLoadTimings(generationMilliseconds: generationMilliseconds,
                                 insertionMilliseconds: insertionMilliseconds,
                                 saveMilliseconds: saveMilliseconds,
                                 sessions: sessions.count, activities: activities.count,
                                 metrics: metrics.count, entries: entries.count,
                                 totalSessions: sessions.count, totalActivities: activities.count,
                                 totalMetrics: metrics.count, totalEntries: entries.count,
                                 extraSessions: 0, extraActivities: 0, extraMetrics: 0, extraEntries: 0)
    }

    nonisolated private static func assignUniqueNames<Model>(to models: [Model], avoiding existingNames: [String]) where Model: AnyObject {
        var usedNames = Set(existingNames.map(normalizedName))
        for model in models {
            let name: String
            if let activity = model as? Activity { name = activity.name }
            else if let metric = model as? Metric { name = metric.name }
            else { continue }
            var candidate = name
            if usedNames.contains(normalizedName(candidate)) {
                candidate = "\(name) (Sample)"
                var suffix = 2
                while usedNames.contains(normalizedName(candidate)) {
                    candidate = "\(name) (Sample \(suffix))"
                    suffix += 1
                }
            }
            usedNames.insert(normalizedName(candidate))
            if let activity = model as? Activity { activity.name = candidate }
            else if let metric = model as? Metric { metric.name = candidate }
        }
    }

    nonisolated private static func normalizedName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private struct GeneratedSampleData {
        let activities: [Activity]
        let metrics: [Metric]
        let sessions: [Session]
        let entries: [MetricEntry]
        let firstDay: Date
    }

    private static func makeSampleData(now: Date) throws -> GeneratedSampleData {
        let activities = [
            Activity(name: "Math", colorHex: Theme.activityColorPresets[0], iconName: "function"),
            Activity(name: "Personal Projects", colorHex: Theme.activityColorPresets[1], iconName: "laptopcomputer"),
            Activity(name: "Chess", colorHex: Theme.activityColorPresets[2], iconName: "crown"),
            Activity(name: "Walks", colorHex: Theme.activityColorPresets[5], iconName: "figure.walk"),
            Activity(name: "Extraordinary Long-Term Personal Research and Creative Projects", colorHex: Theme.activityColorPresets[6], iconName: "sparkles"),
            Activity(name: "Language Study", colorHex: Theme.activityColorPresets[7], iconName: "character.book.closed"),
            Activity(name: "Music Practice", colorHex: Theme.activityColorPresets[3], iconName: "music.note")
        ]
        let metrics = [Metric(name: "Sleep Score", unit: "pts"), Metric(name: "ZetaMac", unit: "pts"),
                       Metric(name: "Chess Rating", unit: "")]
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let firstDay = calendar.date(byAdding: .day, value: -59, to: start) ?? start
        var sessions: [Session] = []
        var entries: [MetricEntry] = []
        let sharedPhoto = gradientPhoto()
        let notes = ["Problem sets and review", "Built a small feature", "Tactics and a rapid game", "A walk to reset",
                     "Research, planning and creative work", "Vocabulary and grammar drills", "Scales, rhythm and focused practice"]

        for day in 0..<60 {
            guard let base = calendar.date(byAdding: .day, value: -day, to: start) else { continue }
            let progress = Double(59 - day) / 59

            if !zeroDays.contains(day) {
                for slot in 0..<3 {
                    let index = (day + slot * 2) % activities.count
                    let activity = activities[index]
                    let date = sessionDate(day: day, index: index, base: base, now: now, calendar: calendar)
                    let photo = day < 4 && slot == day % 3 ? sharedPhoto : nil
                    let note = day == 2 && slot == 0
                        ? "A deliberately longer recap note to check that text stays safely within the card layout."
                        : notes[index]
                    sessions.append(Session(date: date, hours: sessionHours(day: day, index: index),
                                            note: note, photoData: photo, activity: activity))
                }
            }

            if day < 50 && day.isMultiple(of: 2) {
                for (index, metric) in metrics.enumerated() {
                    let wave = sin(Double(day) * 1.3 + Double(index))
                    let value: Double
                    switch index {
                    case 0: value = min(95, max(60, 62 + progress * 30 + wave * 3))
                    case 1: value = min(70, max(30, 32 + progress * 36 + wave * 4))
                    default: value = min(950, max(800, 810 + progress * 135 + wave * 12))
                    }
                    let date = metricDate(day: day, index: index, base: base, now: now, calendar: calendar)
                    entries.append(MetricEntry(date: date, value: value.rounded(), metric: metric))
                }
            }
        }
        return GeneratedSampleData(activities: activities, metrics: metrics, sessions: sessions,
                                   entries: entries, firstDay: firstDay)
    }

    private static func gradientPhoto() -> Data? {
        #if os(iOS)
        let size = CGSize(width: 320, height: 400)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let colors = [UIColor(Theme.accent).cgColor, UIColor(Theme.surface).cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { return }
            context.cgContext.drawLinearGradient(gradient, start: .zero,
                                                 end: CGPoint(x: size.width, y: size.height), options: [])
        }
        return image.jpegData(compressionQuality: 0.65)
        #else
        return nil
        #endif
    }

    private static func sessionHours(day: Int, index: Int) -> Double {
        var value = sampleSeed &+ UInt64(day * 7 + index + 1)
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        value ^= value >> 31
        let fraction = Double(value >> 11) / Double(1 << 53)
        let typical = [1.6, 2.0, 0.75, 0.5, 1.25, 0.75, 0.5][index]
        let hours = min(12, max(0.25, typical + fraction * 1.5 - 0.5))
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

    @MainActor
    static func runSampleDataSelfCheck() -> String {
        do {
            let schema = Schema([Activity.self, Session.self, Metric.self, MetricEntry.self])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)
            context.autosaveEnabled = false

            let firstTimings = try load(into: context, now: Date(timeIntervalSince1970: 1_800_000_000))
            let first = try counts(in: context)
            let badHours = try context.fetch(FetchDescriptor<Session>()).filter {
                !$0.hours.isFinite || !(0.25...12).contains($0.hours)
            }.count
            guard first.sessions <= 260, badHours == 0, first.activities == 7,
                  first.metrics == 3, (60...90).contains(first.entries) else {
                return "FAIL: first run \(first); invalid hours=\(badHours)"
            }

            let replacementTimings = try load(into: context, replacingExisting: true,
                                               now: Date(timeIntervalSince1970: 1_800_000_000))
            let second = try counts(in: context)
            guard second == first else {
                return "FAIL: first run \(first); replace run \(second)"
            }
            return "PASS: first run \(first); replace run \(second); invalid hours=0; first load \(firstTimings); replace load \(replacementTimings)"
        } catch {
            return "FAIL: sample generator check threw \(error.localizedDescription)"
        }
    }

    struct Counts: Equatable, CustomStringConvertible {
        let sessions: Int
        let activities: Int
        let metrics: Int
        let entries: Int
        var description: String {
            "sessions=\(sessions), activities=\(activities), metrics=\(metrics), entries=\(entries)"
        }
    }

    static func counts(in context: ModelContext) throws -> Counts {
        Counts(sessions: try context.fetchCount(FetchDescriptor<Session>()),
               activities: try context.fetchCount(FetchDescriptor<Activity>()),
               metrics: try context.fetchCount(FetchDescriptor<Metric>()),
               entries: try context.fetchCount(FetchDescriptor<MetricEntry>()))
    }

    static func clear(_ context: ModelContext) throws {
        for session in try context.fetch(FetchDescriptor<Session>()) { context.delete(session) }
        for entry in try context.fetch(FetchDescriptor<MetricEntry>()) { context.delete(entry) }
        for activity in try context.fetch(FetchDescriptor<Activity>()) { context.delete(activity) }
        for metric in try context.fetch(FetchDescriptor<Metric>()) { context.delete(metric) }
        try context.save()
    }
}

enum SampleDataError: LocalizedError {
    case invalidGeneratedData

    var errorDescription: String? {
        switch self {
        case .invalidGeneratedData:
            "Generated sample data failed count or session-hours validation."
        }
    }
}
#endif
