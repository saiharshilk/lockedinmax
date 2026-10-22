import Foundation

// Calendar-based time breakdowns and metric range summaries; all functions are deterministic for their inputs.
enum StatsPeriodKind: String, CaseIterable, Identifiable {
    case day = "DAY", week = "WEEK", month = "MONTH"
    var id: String { rawValue }
}

enum StatsFormat {
    static func day(_ date: Date, calendar: Calendar = .current) -> String {
        dateFormatter("EEE d MMM", calendar: calendar).string(from: date).uppercased()
    }

    static func period(_ kind: StatsPeriodKind, period: StatsAnalytics.Period,
                       calendar: Calendar = .current) -> String {
        switch kind {
        case .day:
            return day(period.start, calendar: calendar)
        case .week:
            let last = calendar.date(byAdding: .day, value: 6, to: period.start) ?? period.start
            let startMonth = calendar.component(.month, from: period.start)
            let endMonth = calendar.component(.month, from: last)
            let startYear = calendar.component(.year, from: period.start)
            let endYear = calendar.component(.year, from: last)
            if startMonth == endMonth && startYear == endYear {
                return "\(calendar.component(.day, from: period.start)) – \(dateFormatter("d MMM", calendar: calendar).string(from: last))".uppercased()
            }
            let startFormat = startYear == endYear ? "d MMM" : "d MMM yyyy"
            let endFormat = startYear == endYear ? "d MMM" : "d MMM yyyy"
            return "\(dateFormatter(startFormat, calendar: calendar).string(from: period.start)) – \(dateFormatter(endFormat, calendar: calendar).string(from: last))".uppercased()
        case .month:
            let formatter = dateFormatter("MMMM yyyy", calendar: calendar)
            return formatter.string(from: period.start).uppercased()
        }
    }

    private static func dateFormatter(_ format: String, calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = format
        return formatter
    }
}

enum StatsAnalytics {
    struct Period {
        let start: Date
        let end: Date
        let previousStart: Date
        let previousEnd: Date
        let bucketDates: [Date]
    }

    struct ActivitySlice: Identifiable {
        let id: UUID
        let name: String
        let colorHex: String
        let iconName: String
        let hours: Double
        let share: Double
    }

    struct BucketValue: Identifiable {
        let bucket: Int
        let activityID: UUID
        let activityName: String
        let hours: Double
        var id: String { "\(bucket)-\(activityID.uuidString)" }
    }

    struct Summary {
        let period: Period
        let bucketValues: [BucketValue]
        let totalHours: Double
        let previousHours: Double
        let deltaHours: Double
        let deltaPercent: Double?
        let comparisonCaption: String
        let elapsedDays: Int
        let breakdown: [ActivitySlice]
        let activeDays: Int
        let daysSoFar: Int
        let averagePerActiveDay: Double
        let bestDay: (date: Date, hours: Double)?
        let topPosition: ActivitySlice?
    }

    struct HeatDay: Identifiable {
        let date: Date
        let hours: Double
        let level: Int
        let isToday: Bool
        let isFuture: Bool
        var id: Date { date }
    }

    static func period(kind: StatsPeriodKind, anchor: Date, calendar: Calendar = .current) -> Period {
        let interval: DateInterval
        switch kind {
        case .day:
            let start = calendar.startOfDay(for: anchor)
            interval = DateInterval(start: start, end: calendar.date(byAdding: .day, value: 1, to: start) ?? start)
        case .week:
            interval = calendar.dateInterval(of: .weekOfYear, for: anchor)
                ?? DateInterval(start: calendar.startOfDay(for: anchor), duration: 7 * 86_400)
        case .month:
            interval = calendar.dateInterval(of: .month, for: anchor)
                ?? DateInterval(start: calendar.startOfDay(for: anchor), duration: 31 * 86_400)
        }
        let previousStart = calendar.date(byAdding: kind == .month ? .month : kind == .week ? .weekOfYear : .day,
                                          value: -1, to: interval.start) ?? interval.start
        let count: Int
        switch kind {
        case .day: count = 24
        case .week: count = 7
        case .month: count = calendar.range(of: .day, in: .month, for: interval.start)?.count ?? 30
        }
        let dates: [Date]
        if kind == .day {
            dates = (0..<24).compactMap { hour in
                calendar.date(bySettingHour: hour, minute: 0, second: 0, of: interval.start)
                    ?? interval.start.addingTimeInterval(Double(hour) * 3_600)
            }
        } else {
            dates = (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
        }
        return Period(start: interval.start, end: interval.end, previousStart: previousStart,
                      previousEnd: interval.start, bucketDates: dates)
    }

    static func summarize(sessions: [Session], kind: StatsPeriodKind, anchor: Date, now: Date,
                          calendar: Calendar = .current) -> Summary {
        Analytics.recordRecompute()
#if DEBUG
        if DebugWorkState.isSeeding {
            let period = period(kind: kind, anchor: anchor, calendar: calendar)
            return Summary(period: period, bucketValues: [], totalHours: 0, previousHours: 0,
                           deltaHours: 0, deltaPercent: nil, comparisonCaption: "", elapsedDays: 0, breakdown: [], activeDays: 0,
                           daysSoFar: 0, averagePerActiveDay: 0, bestDay: nil, topPosition: nil)
        }
#endif
        let period = period(kind: kind, anchor: anchor, calendar: calendar)
        let isCurrentPeriod = now >= period.start && now < period.end
        let current = sessions.filter { $0.hours.isFinite && $0.date >= period.start && $0.date < period.end && $0.date <= now }
        let elapsedDays: Int
        if kind == .day {
            elapsedDays = 1
        } else if isCurrentPeriod {
            elapsedDays = max(1, (calendar.dateComponents([.day], from: period.start,
                                                         to: calendar.startOfDay(for: now)).day ?? 0) + 1)
        } else {
            elapsedDays = period.bucketDates.count
        }
        let previousEnd: Date
        if isCurrentPeriod && kind != .day {
            let previousPeriodEnd = period.start
            let previousPeriodDays = calendar.dateComponents([.day], from: period.previousStart,
                                                              to: previousPeriodEnd).day ?? elapsedDays
            let matchedDays = min(elapsedDays, previousPeriodDays)
            previousEnd = calendar.date(byAdding: .day, value: matchedDays, to: period.previousStart)
                .map { min($0, previousPeriodEnd) } ?? previousPeriodEnd
        } else {
            previousEnd = period.previousEnd
        }
        let previous = sessions.filter { $0.hours.isFinite && $0.date >= period.previousStart && $0.date < previousEnd }
        let comparisonCaption: String
        switch kind {
        case .day: comparisonCaption = "vs yesterday"
        case .week: comparisonCaption = isCurrentPeriod ? "vs same days last week" : "vs previous week"
        case .month: comparisonCaption = isCurrentPeriod ? "vs same days last month" : "vs previous month"
        }
        var buckets: [Int: [UUID: Double]] = [:]
        var models: [UUID: Activity] = [:]
        var days: [Date: Double] = [:]
        var positions: [UUID: Double] = [:]
        var currentGuard = LoopGuard("StatsAnalytics.summarize.current")
        for session in current {
            guard currentGuard.next() else { break }
            let hours = Analytics.boundedHours(session.hours)
            let date = calendar.startOfDay(for: session.date)
            days[date, default: 0] += hours
            guard let activity = session.activity else { continue }
            models[activity.id] = activity
            let index = bucketIndex(session.date, kind: kind, period: period, calendar: calendar)
            if period.bucketDates.indices.contains(index) { buckets[index, default: [:]][activity.id, default: 0] += hours }
            positions[activity.id, default: 0] += hours
        }
        let total = current.reduce(0) { $0 + Analytics.boundedHours($1.hours) }
        let prior = previous.reduce(0) { $0 + Analytics.boundedHours($1.hours) }
        let breakdown = positions.compactMap { id, hours -> ActivitySlice? in
            guard let model = models[id] else { return nil }
            return ActivitySlice(id: id, name: model.name, colorHex: model.colorHex, iconName: model.iconName,
                                 hours: hours, share: total > 0 ? hours / total : 0)
        }.sorted { $0.hours == $1.hours ? $0.name < $1.name : $0.hours > $1.hours }
        let today = calendar.startOfDay(for: now)
        let dayAfterToday = calendar.date(byAdding: .day, value: 1, to: today) ?? period.end
        let effectiveEnd = min(period.end, dayAfterToday)
        let daysSoFar = min(period.bucketDates.count,
                            max(0, calendar.dateComponents([.day], from: period.start, to: effectiveEnd).day ?? 0))
        let active = days.keys.filter { $0 < effectiveEnd }.count
        let dayEntries: [(date: Date, hours: Double)] = days.map { entry in
            (date: entry.key, hours: entry.value)
        }
        let sortedDays = dayEntries.sorted { lhs, rhs in
            if lhs.hours == rhs.hours { return lhs.date < rhs.date }
            return lhs.hours > rhs.hours
        }
        let best = sortedDays.first
        let delta = total - prior
        let chartValues = period.bucketDates.indices.flatMap { bucket in
            models.keys.sorted { (models[$0]?.name ?? "") < (models[$1]?.name ?? "") }.map { id in
                BucketValue(bucket: bucket, activityID: id, activityName: models[id]?.name ?? "",
                            hours: buckets[bucket, default: [:]][id, default: 0])
            }
        }
        return Summary(period: period, bucketValues: chartValues, totalHours: total, previousHours: prior,
                       deltaHours: delta, deltaPercent: Analytics.percentChange(current: total, previous: prior),
                       comparisonCaption: comparisonCaption, elapsedDays: isCurrentPeriod ? elapsedDays : period.bucketDates.count,
                       breakdown: breakdown, activeDays: active, daysSoFar: daysSoFar,
                       averagePerActiveDay: active > 0 ? total / Double(active) : 0,
                       bestDay: best, topPosition: breakdown.first)
    }

    private static func bucketIndex(_ date: Date, kind: StatsPeriodKind, period: Period,
                                    calendar: Calendar) -> Int {
        if kind == .day { return calendar.component(.hour, from: date) }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: period.start),
                                       to: calendar.startOfDay(for: date)).day ?? 0
    }

    /// Heat levels use quartiles of non-zero daily totals; empty days always have level zero.
    static func heatmap(sessions: [Session], today: Date, calendar: Calendar = .current) -> [HeatDay] {
        Analytics.recordRecompute()
        let end = calendar.startOfDay(for: today)
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: end)?.start ?? end
        let first = calendar.date(byAdding: .weekOfYear, value: -11, to: currentWeekStart) ?? currentWeekStart
        let currentWeekEnd = calendar.date(byAdding: .day, value: 6, to: currentWeekStart) ?? end
        let heatmapEnd = calendar.date(byAdding: .day, value: 1, to: currentWeekEnd) ?? currentWeekEnd
        var totals: [Date: Double] = [:]
        var sessionGuard = LoopGuard("StatsAnalytics.heatmap.sessions")
        let dayAfterToday = calendar.date(byAdding: .day, value: 1, to: end) ?? end
        for session in sessions where session.hours.isFinite && session.date >= first
            && session.date < heatmapEnd && session.date < dayAfterToday {
            guard sessionGuard.next() else { break }
            let day = calendar.startOfDay(for: session.date)
            totals[day, default: 0] += Analytics.boundedHours(session.hours)
        }
        let maximumHours = totals.values.filter(\.isFinite).max() ?? 0
        var dayGuard = LoopGuard("StatsAnalytics.heatmap.days")
        return (0..<84).compactMap { offset in
            guard dayGuard.next(),
                  let date = calendar.date(byAdding: .day, value: offset, to: first) else { return nil }
            let day = calendar.startOfDay(for: date)
            let rawHours = totals[day, default: 0]
            let hours = rawHours.isFinite ? max(0, rawHours) : 0
            let ratio = maximumHours > 0 && maximumHours.isFinite ? hours / maximumHours : 0
            let level = hours == 0 ? 0 : min(4, max(1, Int(ceil(ratio * 4))))
            return HeatDay(date: day, hours: hours, level: level,
                           isToday: calendar.isDate(day, inSameDayAs: end), isFuture: day > end)
        }
    }
}
