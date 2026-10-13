import Foundation
import SwiftData

enum TimeRange: String, CaseIterable, Identifiable {
    case day = "1D"
    case week = "1W"
    case month = "1M"
    case quarter = "3M"
    case year = "1Y"
    case all = "ALL"

    var id: String { rawValue }
}

enum Analytics {
    struct ChartPoint: Identifiable {
        let id: Int
        let date: Date
        let value: Double
    }

    struct Position: Identifiable {
        let id: UUID
        let name: String
        let colorHex: String
        let iconName: String
        let hours: Double
        let deltaHours: Double?
        let deltaPercent: Double?
    }

    struct Summary {
        let windowStart: Date
        let windowEnd: Date
        let previousStart: Date?
        let previousEnd: Date?
        let currentHours: Double
        let previousHours: Double?
        let deltaHours: Double?
        let deltaPercent: Double?
        let buckets: [ChartPoint]
        let cumulative: [ChartPoint]
        let positions: [Position]
    }

    private struct TimeWindow {
        let start: Date
        let end: Date
    }

    static func summarize(sessions: [Session], range: TimeRange, now: Date = .now,
                          calendar: Calendar = .current) -> Summary {
        let (current, previous) = window(for: range, sessions: sessions, now: now, calendar: calendar)
        let currentHours = total(sessions, from: current.start, to: current.end, includeEnd: true)
        let previousHours = previous.map { total(sessions, from: $0.start, to: $0.end, includeEnd: false) }
        let deltaHours = previousHours.map { currentHours - $0 }
        let deltaPercent: Double? = previousHours.flatMap { previous in
            guard previous > 0 else { return nil }
            return (currentHours - previous) / previous * 100
        }
        let points = chartPoints(sessions: sessions, window: current, range: range, calendar: calendar)
        return Summary(
            windowStart: current.start,
            windowEnd: current.end,
            previousStart: previous?.start,
            previousEnd: previous?.end,
            currentHours: currentHours,
            previousHours: previousHours,
            deltaHours: deltaHours,
            deltaPercent: deltaPercent,
            buckets: points.buckets,
            cumulative: points.cumulative,
            positions: positions(sessions: sessions, current: current, previous: previous)
        )
    }

    static func deltaText(hours: Double, percent: Double?) -> String {
        let magnitude = abs(hours).formatted(.number.precision(.fractionLength(0...1)))
        guard let percent else { return "\(magnitude) hrs" }
        let sign = percent > 0 ? "+" : ""
        let percentText = percent.formatted(.number.precision(.fractionLength(0...1)))
        return "\(magnitude) hrs (\(sign)\(percentText)%)"
    }

    private static func window(for range: TimeRange, sessions: [Session], now: Date,
                               calendar: Calendar) -> (TimeWindow, TimeWindow?) {
        switch range {
        case .day:
            let start = calendar.startOfDay(for: now)
            let previousStart = calendar.date(byAdding: .day, value: -1, to: start) ?? start
            return (TimeWindow(start: start, end: now), TimeWindow(start: previousStart, end: start))
        case .week, .month, .quarter, .year:
            let days: Int
            switch range {
            case .week: days = 7
            case .month: days = 30
            case .quarter: days = 90
            case .year: days = 365
            case .day, .all: days = 7
            }
            let start = calendar.date(byAdding: .day, value: -days, to: now) ?? now
            let previousStart = calendar.date(byAdding: .day, value: -days, to: start) ?? start
            return (TimeWindow(start: start, end: now), TimeWindow(start: previousStart, end: start))
        case .all:
            let earliest = sessions.map(\.date).min()
            let start = earliest.map { min($0, now) } ?? now
            return (TimeWindow(start: start, end: now), nil)
        }
    }

    private static func total(_ sessions: [Session], from start: Date, to end: Date,
                              includeEnd: Bool) -> Double {
        sessions.reduce(0) { total, session in
            guard session.date >= start,
                  includeEnd ? session.date <= end : session.date < end else { return total }
            return total + session.hours
        }
    }

    private static func chartPoints(sessions: [Session], window: TimeWindow, range: TimeRange,
                                    calendar: Calendar) -> (buckets: [ChartPoint], cumulative: [ChartPoint]) {
        guard window.end > window.start else {
            let point = ChartPoint(id: 0, date: window.start, value: 0)
            return ([point], [point])
        }
        let component = bucketComponent(for: range, window: window, calendar: calendar)
        var buckets: [ChartPoint] = []
        var cumulative = [ChartPoint(id: 0, date: window.start, value: 0)]
        var running = 0.0
        var segmentStart = calendar.dateInterval(of: component, for: window.start)?.start ?? window.start

        while segmentStart < window.end {
            guard let interval = calendar.dateInterval(of: component, for: segmentStart),
                  interval.end > segmentStart else { break }
            let start = max(segmentStart, window.start)
            let end = min(interval.end, window.end)
            if end > start {
                let hours = total(sessions, from: start, to: end, includeEnd: end == window.end)
                buckets.append(ChartPoint(id: buckets.count, date: start, value: hours))
                running += hours
                cumulative.append(ChartPoint(id: cumulative.count, date: end, value: running))
            }
            segmentStart = interval.end
        }
        return (buckets, cumulative)
    }

    private static func bucketComponent(for range: TimeRange, window: TimeWindow,
                                        calendar: Calendar) -> Calendar.Component {
        switch range {
        case .day: return Calendar.Component.hour
        case .week, .month, .quarter: return Calendar.Component.day
        case .year: return Calendar.Component.weekOfYear
        case .all:
            let twoYears = calendar.date(byAdding: .year, value: 2, to: window.start)
            if let twoYears, window.end > twoYears {
                return Calendar.Component.month
            }
            return Calendar.Component.weekOfYear
        }
    }

    private static func positions(sessions: [Session], current: TimeWindow,
                                  previous: TimeWindow?) -> [Position] {
        var currentHours: [UUID: Double] = [:]
        var previousHours: [UUID: Double] = [:]
        var activities: [UUID: Activity] = [:]

        for session in sessions {
            guard let activity = session.activity else { continue }
            activities[activity.id] = activity
            if session.date >= current.start && session.date <= current.end {
                currentHours[activity.id, default: 0] += session.hours
            }
            if let previous, session.date >= previous.start, session.date < previous.end {
                previousHours[activity.id, default: 0] += session.hours
            }
        }

        return currentHours.compactMap { id, hours in
            guard hours > 0, let activity = activities[id] else { return nil }
            let prior: Double? = previous == nil ? nil : (previousHours[id] ?? 0)
            let delta = prior.map { hours - $0 }
            let percent = prior.flatMap { prior -> Double? in
                guard prior > 0 else { return nil }
                return (hours - prior) / prior * 100
            }
            return Position(id: id, name: activity.name, colorHex: activity.colorHex,
                            iconName: activity.iconName, hours: hours, deltaHours: delta,
                            deltaPercent: percent)
        }
        .sorted {
            $0.hours == $1.hours ? $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                                 : $0.hours > $1.hours
        }
    }
}

extension TimeRange {
    var displayName: String {
        switch self {
        case .day: "TODAY"
        case .week: "LAST 7 DAYS"
        case .month: "LAST 30 DAYS"
        case .quarter: "LAST 90 DAYS"
        case .year: "LAST YEAR"
        case .all: "ALL TIME"
        }
    }
}
