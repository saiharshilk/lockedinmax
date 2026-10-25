import Foundation
import SwiftUI
#if os(iOS)
import UIKit
#endif

struct RecapSessionValue: Identifiable {
    let id: UUID
    let date: Date
    let hours: Double
    let activityID: UUID?
    let activityName: String
    let activityColorHex: String
    let iconName: String
    let note: String
    let photo: UIImage?
    let photoData: Data?

    init(id: UUID = UUID(), date: Date, hours: Double, activityID: UUID?, activityName: String,
         activityColorHex: String, iconName: String = "circle.fill", note: String = "",
         photo: UIImage? = nil, photoData: Data? = nil) {
        self.id = id
        self.date = date
        self.hours = hours
        self.activityID = activityID
        self.activityName = activityName
        self.activityColorHex = activityColorHex
        self.iconName = iconName
        self.note = note
        self.photo = photo
        self.photoData = photoData
    }

    init(model: Session, includePhoto: Bool = false) {
        self.init(id: model.id, date: model.date, hours: model.hours,
                  activityID: model.activity?.id, activityName: model.activity?.name ?? "SESSION",
                  activityColorHex: model.activity?.colorHex ?? "#CCFF00",
                  iconName: model.activity?.iconName ?? "circle.fill", note: model.note,
                  photo: includePhoto ? model.photoData.flatMap(UIImage.init(data:)) : nil,
                  photoData: model.photoData)
    }
}

struct RecapScoreValue: Identifiable {
    let id: UUID
    let date: Date
    let metricName: String
    let value: Double

    init(id: UUID = UUID(), date: Date, metricName: String, value: Double) {
        self.id = id
        self.date = date
        self.metricName = metricName
        self.value = value
    }

    init(model: MetricEntry) {
        self.init(id: model.id, date: model.date, metricName: model.metric?.name ?? "SCORE", value: model.value)
    }
}

struct SessionRecapCardData {
    let session: RecapSessionValue
    let activityHistory: [RecapSessionValue]
    let allSessions: [RecapSessionValue]
    let daySessions: [RecapSessionValue]
    let previousDaySessions: [RecapSessionValue]
    let scores: [RecapScoreValue]
    let todayHours: Double
    let weekHours: Double
    let streakDays: Int
    let caption: String
    let format: RecapCardFormat
    let background: RecapCardBackground

    init(session: RecapSessionValue, activityHistory: [RecapSessionValue], allSessions: [RecapSessionValue],
         daySessions: [RecapSessionValue], previousDaySessions: [RecapSessionValue], scores: [RecapScoreValue],
         todayHours: Double = 0, weekHours: Double = 0, streakDays: Int = 0, caption: String,
         format: RecapCardFormat, background: RecapCardBackground) {
        self.session = session; self.activityHistory = activityHistory; self.allSessions = allSessions
        self.daySessions = daySessions; self.previousDaySessions = previousDaySessions; self.scores = scores
        self.todayHours = todayHours; self.weekHours = weekHours; self.streakDays = streakDays
        self.caption = caption; self.format = format; self.background = background
    }
}

struct MarketCloseCardData {
    let date: Date
    let sessions: [RecapSessionValue]
    let previousDaySessions: [RecapSessionValue]
    let sevenDayHours: [Double]
    let scores: [MarketScoreValue]
    let format: RecapCardFormat
    let background: RecapCardBackground

    init(date: Date, sessions: [RecapSessionValue], previousDaySessions: [RecapSessionValue],
         sevenDayHours: [Double] = [], scores: [MarketScoreValue], format: RecapCardFormat,
         background: RecapCardBackground = .dark) {
        self.date = date; self.sessions = sessions; self.previousDaySessions = previousDaySessions
        self.sevenDayHours = sevenDayHours; self.scores = scores; self.format = format; self.background = background
    }
}

struct MarketScoreValue: Identifiable {
    let id: UUID
    let name: String
    let value: Double
    let change: Double?
}

struct WeeklyPositionValue: Identifiable {
    let id: UUID
    let name: String
    let colorHex: String
    let hours: Double
    let share: Double
}

struct WeeklyDayValue: Identifiable {
    let date: Date
    let total: Double
    let stacks: [WeeklyPositionValue]
    let isFuture: Bool
    var id: Date { date }
}

struct WeeklyScoreValue: Identifiable {
    let id: UUID
    let name: String
    let value: Double
    let change: Double?
}

struct WeeklyCardData {
    let startDate: Date
    let days: [WeeklyDayValue]
    let positions: [WeeklyPositionValue]
    let scores: [WeeklyScoreValue]
    let totalHours: Double
    let previousHours: Double
    let deltaHours: Double
    let deltaPercent: Double?
    let comparisonCaption: String
    let activeDays: Int
    let elapsedDays: Int
    let averagePerActiveDay: Double
    let streakDays: Int
    let isCurrentWeek: Bool
    let format: RecapCardFormat
    let background: RecapCardBackground
}

@MainActor
enum RecapCardFactory {
    static func session(_ selected: Session, allSessions: [Session], scores: [MetricEntry],
                        caption: String, format: RecapCardFormat,
                        background: RecapCardBackground) -> SessionRecapCardData {
        let calendar = Calendar.current
        let activityHistory = allSessions.filter { $0.activity?.id == selected.activity?.id && $0.date <= selected.date }
            .sorted { $0.date < $1.date }.suffix(14).map { RecapSessionValue(model: $0) }
        let day = allSessions.filter { calendar.isDate($0.date, inSameDayAs: selected.date) }
            .map { RecapSessionValue(model: $0, includePhoto: true) }
        let previousDate = calendar.date(byAdding: .day, value: -1,
                                         to: calendar.startOfDay(for: selected.date)) ?? selected.date
        let previous = allSessions.filter { calendar.isDate($0.date, inSameDayAs: previousDate) }
            .map { RecapSessionValue(model: $0, includePhoto: true) }
        let sameDayScores = scores.filter { calendar.isDate($0.date, inSameDayAs: selected.date) }
            .map(RecapScoreValue.init(model:))
        let week = StatsAnalytics.period(kind: .week, anchor: selected.date, calendar: calendar)
        let weekHours = allSessions.filter { $0.date >= week.start && $0.date < week.end && $0.date <= selected.date
            && $0.activity?.id == selected.activity?.id }
            .reduce(0) { $0 + Analytics.boundedHours($1.hours) }
        let sessionDays = Set(allSessions.filter { $0.date <= selected.date }.map { calendar.startOfDay(for: $0.date) })
        var streak = 0
        var cursor = calendar.startOfDay(for: selected.date)
        while sessionDays.contains(cursor) {
            streak += 1
            guard let prior = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prior
        }
        return SessionRecapCardData(session: RecapSessionValue(model: selected, includePhoto: true),
                                    activityHistory: activityHistory,
                                    allSessions: allSessions.map { RecapSessionValue(model: $0, includePhoto: true) },
                                    daySessions: day, previousDaySessions: previous, scores: sameDayScores,
                                    todayHours: day.reduce(0) { $0 + Analytics.boundedHours($1.hours) },
                                    weekHours: weekHours, streakDays: streak,
                                    caption: String(caption.prefix(80)), format: format, background: background)
    }

    static func marketClose(_ date: Date, sessions: [Session], scores: [MetricEntry],
                            format: RecapCardFormat, background: RecapCardBackground = .dark) -> MarketCloseCardData {
        let calendar = Calendar.current
        let day = sessions.filter { calendar.isDate($0.date, inSameDayAs: date) }
            .map { RecapSessionValue(model: $0, includePhoto: true) }
        let previousDate = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: date)) ?? date
        let previous = sessions.filter { calendar.isDate($0.date, inSameDayAs: previousDate) }
            .map { RecapSessionValue(model: $0, includePhoto: true) }
        let weekStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: date)) ?? date
        let weekHours = (0..<7).map { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return 0.0 }
            return sessions.filter { calendar.isDate($0.date, inSameDayAs: day) }
                .reduce(0) { $0 + Analytics.boundedHours($1.hours) }
        }
        let dayScores = scores.filter { calendar.isDate($0.date, inSameDayAs: date) }.sorted { $0.date > $1.date }
        var latestByMetric: [String: MetricEntry] = [:]
        for score in scores where score.date < calendar.startOfDay(for: date) {
            let name = score.metric?.name ?? "SCORE"
            if let existing = latestByMetric[name] {
                if existing.date < score.date { latestByMetric[name] = score }
            } else { latestByMetric[name] = score }
        }
        let scoreValues = dayScores.reduce(into: [String: MetricEntry]()) { result, entry in
            let name = entry.metric?.name ?? "SCORE"
            if result[name] == nil { result[name] = entry }
        }.values.map { entry in
            let name = entry.metric?.name ?? "SCORE"
            let prior = latestByMetric[name]?.value
            return MarketScoreValue(id: entry.id, name: name, value: entry.value,
                                    change: prior.map { entry.value - $0 })
        }.sorted { $0.name < $1.name }
        return MarketCloseCardData(date: date, sessions: day, previousDaySessions: previous,
                                   sevenDayHours: weekHours, scores: scoreValues, format: format,
                                   background: background)
    }

    static func weekly(_ anchor: Date, sessions: [Session], scores: [MetricEntry], now: Date = .now,
                       format: RecapCardFormat, background: RecapCardBackground = .dark,
                       calendar: Calendar = .current) -> WeeklyCardData {
        let summary = StatsAnalytics.summarize(sessions: sessions, kind: .week, anchor: anchor,
                                               now: now, calendar: calendar)
        let start = summary.period.start
        let today = calendar.startOfDay(for: now)
        let values = sessions.filter { $0.hours.isFinite && $0.date >= start && $0.date < summary.period.end && $0.date <= now }
        var byDayPosition: [Date: [UUID: Double]] = [:]
        var positionsByID: [UUID: WeeklyPositionValue] = [:]
        for session in values {
            guard let activity = session.activity else { continue }
            let day = calendar.startOfDay(for: session.date)
            byDayPosition[day, default: [:]][activity.id, default: 0] += Analytics.boundedHours(session.hours)
            let hours = summary.breakdown.first(where: { $0.id == activity.id })?.hours ?? 0
            positionsByID[activity.id] = WeeklyPositionValue(id: activity.id, name: activity.name,
                colorHex: activity.colorHex, hours: hours,
                share: summary.totalHours > 0 ? hours / summary.totalHours : 0)
        }
        let days = summary.period.bucketDates.map { date -> WeeklyDayValue in
            let day = calendar.startOfDay(for: date)
            let future = day > today
            let stacks = positionsByID.values.compactMap { position -> WeeklyPositionValue? in
                let hours = byDayPosition[day, default: [:]][position.id, default: 0]
                guard hours > 0 else { return nil }
                return WeeklyPositionValue(id: position.id, name: position.name, colorHex: position.colorHex,
                                           hours: hours, share: 0)
            }.sorted { $0.name < $1.name }
            return WeeklyDayValue(date: day, total: stacks.reduce(0) { $0 + $1.hours },
                                 stacks: stacks, isFuture: future)
        }
        let weekScores = scores.filter { $0.date >= start && $0.date < summary.period.end && $0.date <= now }
        var scoreGroups: [UUID: [MetricEntry]] = [:]
        for entry in weekScores { scoreGroups[entry.metric?.id ?? entry.id, default: []].append(entry) }
        let scoreValues = scoreGroups.values.compactMap { entries -> WeeklyScoreValue? in
            let ordered = entries.sorted { $0.date < $1.date }
            guard let first = ordered.first, let last = ordered.last, last.value.isFinite else { return nil }
            let change = ordered.count > 1 && first.value.isFinite ? last.value - first.value : nil
            return WeeklyScoreValue(id: last.metric?.id ?? last.id, name: last.metric?.name ?? "SCORE",
                                    value: last.value, change: change)
        }.sorted { $0.name < $1.name }.prefix(3).map { $0 }
        let current = now >= summary.period.start && now < summary.period.end
        let loggedDates = Set(sessions.filter { $0.hours.isFinite && $0.date <= now }
            .map { calendar.startOfDay(for: $0.date) })
        var streak = 0
        var cursor = loggedDates.contains(today) ? today : (calendar.date(byAdding: .day, value: -1, to: today) ?? today)
        while loggedDates.contains(cursor) {
            streak += 1
            guard let prior = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prior
        }
        return WeeklyCardData(startDate: start, days: days, positions: summary.breakdown.prefix(3).map {
            WeeklyPositionValue(id: $0.id, name: $0.name, colorHex: $0.colorHex, hours: $0.hours, share: $0.share)
        }, scores: scoreValues, totalHours: summary.totalHours, previousHours: summary.previousHours,
            deltaHours: summary.deltaHours, deltaPercent: summary.deltaPercent,
            comparisonCaption: summary.comparisonCaption, activeDays: summary.activeDays,
            elapsedDays: current ? summary.elapsedDays : 7, averagePerActiveDay: summary.averagePerActiveDay,
            streakDays: streak, isCurrentWeek: current, format: format, background: background)
    }
}
