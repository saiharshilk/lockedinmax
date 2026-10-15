import SwiftUI
#if os(iOS)
import UIKit
#endif

struct SessionCard: View {
    let session: Session
    let sessions: [Session]
    let daySessions: [Session]
    let sameDayScores: [MetricEntry]
    let caption: String
    let format: RecapCardFormat
    let cardBackground: RecapCardBackground

    private var activityName: String { session.activity?.name ?? "SESSION" }
    private var previousDaySessions: [Session] {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: session.date)) ?? session.date
        return sessions.filter { Calendar.current.isDate($0.date, inSameDayAs: yesterday) }
    }
    private var tickerSessions: [Session] {
        var day = Dictionary(grouping: daySessions.compactMap { item -> (UUID, Session)? in
            guard let id = item.activity?.id else { return nil }
            return (id, item)
        }, by: \.0).values.compactMap { group -> Session? in
            guard let first = group.first?.1 else { return nil }
            return Session(date: first.date, hours: group.reduce(0) { $0 + $1.1.hours }, activity: first.activity)
        }
        day += previousDaySessions
        return day
    }
    private var average: Double {
        let matches = sessions.filter { $0.activity?.id == session.activity?.id }
        guard !matches.isEmpty else { return 0 }
        return matches.reduce(0) { $0 + $1.hours } / Double(matches.count)
    }
    private var delta: Double? {
        let matches = sessions.filter { $0.activity?.id == session.activity?.id }
        guard matches.count > 1, average > 0 else { return nil }
        return (session.hours - average) / average * 100
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            background
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                CardHeader(date: session.date)
                Spacer(minLength: Theme.Spacing.sm)
                Text(activityName)
                    .font(.system(size: 42, weight: .semibold, design: .serif))
                    .foregroundStyle(Theme.accent)
                    .lineLimit(2).minimumScaleFactor(0.55)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.md) {
                    Text("\(Formatters.hoursValue(session.hours)) hrs")
                        .font(.system(size: 30, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.textPrimary).lineLimit(1).minimumScaleFactor(0.7)
                    if let delta {
                        Text("\(delta >= 0 ? "▲" : "▼") \(abs(delta).formatted(.number.precision(.fractionLength(0))))% vs avg")
                            .typography(.caption).foregroundStyle(delta >= 0 ? Theme.up : Theme.down)
                            .lineLimit(1).minimumScaleFactor(0.6)
                    }
                }
                if !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(caption).typography(.body).foregroundStyle(Theme.textSecondary)
                        .lineLimit(2).minimumScaleFactor(0.75).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Theme.Spacing.sm)
                CardFooterTicker(sessions: tickerSessions, previousSessions: previousDaySessions,
                                 scores: sameDayScores)
            }
            .padding(Theme.Spacing.xl)
        }
        .frame(width: format.size.width, height: format.size.height)
        .clipped()
        .background(Theme.background)
    }

    @ViewBuilder private var background: some View {
        if cardBackground == .photo, let data = session.photoData, let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFill()
                .overlay(LinearGradient(colors: [Theme.background.opacity(0.78), Theme.background.opacity(0.28), Theme.background.opacity(0.88)], startPoint: .top, endPoint: .bottom))
        } else {
            Theme.background
            VStack { Spacer(); SkylineShape().fill(Theme.surface).frame(height: format.size.height * 0.28) }
        }
    }
}

#if DEBUG
private enum SessionCardPreviewData {
    static let activity = Activity(name: "Mathematics", colorHex: Theme.activityColorPresets[0], iconName: "function")
    static let date = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 7, hour: 15)) ?? .now
    static let earlier = Session(date: date.addingTimeInterval(-86_400), hours: 3, note: "Earlier study", activity: activity)
    static let photoData: Data? = {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 480, height: 600))
        return renderer.image { context in
            let colors = [UIColor(Theme.accent).cgColor, UIColor(Theme.surface).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 480, y: 600), options: [])
            }
        }.jpegData(compressionQuality: 0.8)
    }()
    static let current = Session(date: date, hours: 4, note: "Problem sets and review", activity: activity)
    static let photo = Session(date: date, hours: 4, note: "Focused work", photoData: photoData, activity: activity)
    static let sameDay = Session(date: date.addingTimeInterval(-3_600), hours: 1.5, note: "Earlier work today", activity: activity)
}

#Preview("Session 4:5 dark") {
    SessionCard(session: SessionCardPreviewData.current,                sessions: [SessionCardPreviewData.earlier, SessionCardPreviewData.current],
                daySessions: [SessionCardPreviewData.current, SessionCardPreviewData.sameDay], sameDayScores: [],
                caption: "Problem sets and review", format: .portrait, cardBackground: .dark)
}
#Preview("Session 9:16 photo") {    SessionCard(session: SessionCardPreviewData.photo,
                sessions: [SessionCardPreviewData.earlier, SessionCardPreviewData.photo],
                daySessions: [SessionCardPreviewData.photo, SessionCardPreviewData.sameDay], sameDayScores: [],
                caption: "Focused work", format: .story, cardBackground: .photo)
}
#endif
