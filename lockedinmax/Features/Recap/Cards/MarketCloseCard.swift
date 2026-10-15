import SwiftUI

struct MarketCloseCard: View {
    let date: Date
    let sessions: [Session]
    let allSessions: [Session]
    let scores: [MetricEntry]
    let format: RecapCardFormat

    private var previousDay: Date { Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: date)) ?? date }
    private var total: Double { sessions.reduce(0) { $0 + $1.hours } }
    private var previousTotal: Double {
        allSessions.filter { Calendar.current.isDate($0.date, inSameDayAs: previousDay) }.reduce(0) { $0 + $1.hours }
    }
    private var rows: [(activity: Activity, hours: Double)] {
        Dictionary(grouping: sessions.compactMap { session -> (Activity, Double)? in
            guard let activity = session.activity else { return nil }
            return (activity, session.hours)
        }, by: { $0.0.id }).compactMap { _, values in
            guard let activity = values.first?.0 else { return nil }
            return (activity, values.reduce(0) { $0 + $1.1 })
        }.sorted { $0.hours > $1.hours }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.background
            VStack { Spacer(); SkylineShape().fill(Theme.surface).frame(height: format.size.height * 0.2) }
                .allowsHitTesting(false)
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                CardHeader(date: date)
                Text("Market Close").font(.system(size: 34, weight: .semibold, design: .serif))
                    .foregroundStyle(Theme.textPrimary).lineLimit(1).minimumScaleFactor(0.7)
                Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased())
                    .typography(.sectionLabel).foregroundStyle(Theme.textSecondary).lineLimit(1)
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.md) {
                    Text("\(Formatters.hoursValue(total)) hrs")
                        .font(.system(size: 31, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.textPrimary).lineLimit(1).minimumScaleFactor(0.65)
                    DeltaLabel(value: total - previousTotal,
                               text: previousTotal == 0 ? "\(Formatters.hoursValue(total - previousTotal)) hrs vs prior" : "\(Formatters.delta(hours: total - previousTotal, percent: (total - previousTotal) / previousTotal * 100)) vs prior")
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(Array(rows.prefix(5).enumerated()), id: \.offset) { _, row in positionRow(row.activity, hours: row.hours) }
                    if rows.count > 5 {
                        Text("+ \(rows.count - 5) MORE POSITIONS").typography(.caption).foregroundStyle(Theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                ForEach(scores.sorted { $0.date < $1.date }.prefix(3)) { entry in
                    HStack {
                        Text((entry.metric?.name ?? "SCORE").uppercased()).typography(.caption).foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Text(Formatters.metricValue(entry.value)).typography(.rowTitle).foregroundStyle(Theme.textPrimary)
                    }
                }
                Spacer(minLength: 0)
                CardFooterTicker(sessions: sessions,
                                 previousSessions: allSessions.filter { Calendar.current.isDate($0.date, inSameDayAs: previousDay) },
                                 scores: scores)
            }
            .padding(Theme.Spacing.xl)
        }
        .frame(width: format.size.width, height: format.size.height)
        .clipped()
    }

    private func positionRow(_ activity: Activity, hours: Double) -> some View {
        VStack(spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.sm) {
                Circle().fill(Theme.activityColor(activity.colorHex)).frame(width: 7, height: 7)
                Text(activity.name).typography(.caption).foregroundStyle(Theme.textPrimary)
                    .lineLimit(1).minimumScaleFactor(0.65)
                Spacer(minLength: Theme.Spacing.xs)
                Text(Formatters.hours(hours)).typography(.rowTitle).foregroundStyle(Theme.textPrimary)
            }
            GeometryReader { geometry in
                Capsule().fill(Theme.hairline).overlay(alignment: .leading) {
                    Capsule().fill(Theme.activityColor(activity.colorHex))
                        .frame(width: geometry.size.width * (total > 0 ? hours / total : 0))
                }
            }.frame(height: 3)
        }
    }
}

#if DEBUG
private enum MarketClosePreviewData {
    static let date = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 7)) ?? .now
    static let activities = (0..<7).map { index in
        Activity(name: ["Math", "Chess", "Real Analysis", "Walks", "Language Study", "Music", "Projects"][index],
                 colorHex: Theme.activityColorPresets[index], iconName: "circle.fill")
    }
    static let sessions = activities.enumerated().map { index, activity in
        Session(date: date, hours: Double(7 - index), note: "Preview session", activity: activity)
    }
    static let previous = activities.prefix(2).map { Session(date: date.addingTimeInterval(-86_400), hours: 1, activity: $0) }
    static let metric = Metric(name: "Sleep Score", unit: "pts")
    static let score = MetricEntry(date: date, value: 84, metric: metric)
}

#Preview("Market Close 4:5") {
    MarketCloseCard(date: MarketClosePreviewData.date, sessions: MarketClosePreviewData.sessions,
                    allSessions: MarketClosePreviewData.sessions + MarketClosePreviewData.previous,
                    scores: [MarketClosePreviewData.score], format: .portrait)
}
#Preview("Market Close 9:16") {
    MarketCloseCard(date: MarketClosePreviewData.date, sessions: MarketClosePreviewData.sessions,
                    allSessions: MarketClosePreviewData.sessions + MarketClosePreviewData.previous,
                    scores: [MarketClosePreviewData.score], format: .story)
}
#endif
