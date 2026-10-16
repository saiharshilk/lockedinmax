import SwiftUI
#if os(iOS)
import UIKit
#endif

struct SessionCard: View {
    let data: SessionRecapCardData

    private var average: Double {
        let values = data.activityHistory.filter { $0.hours.isFinite }
        guard !values.isEmpty else { return 0 }
        return values.reduce(0) { $0 + Analytics.boundedHours($1.hours) } / Double(values.count)
    }

    private var delta: Double? {
        let values = data.activityHistory.filter { $0.hours.isFinite }
        guard values.count > 1, average > 0 else { return nil }
        let result = (Analytics.boundedHours(data.session.hours) - average) / average * 100
        return result.isFinite ? result : nil
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            background
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                CardHeader(date: data.session.date)
                Spacer(minLength: Theme.Spacing.sm)
                Text(data.session.activityName)
                    .font(.system(size: 42, weight: .semibold, design: .serif))
                    .foregroundStyle(Theme.accent).lineLimit(2).minimumScaleFactor(0.55)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.md) {
                    Text(Formatters.hours(data.session.hours))
                        .font(.system(size: 30, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.textPrimary).lineLimit(1).minimumScaleFactor(0.7)
                    if let delta {
                        Text("\(delta >= 0 ? "▲" : "▼") \(abs(delta).formatted(.number.precision(.fractionLength(0))))% vs avg")
                            .typography(.caption).foregroundStyle(delta >= 0 ? Theme.up : Theme.down)
                            .lineLimit(1).minimumScaleFactor(0.6)
                    }
                }
                if !data.caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(data.caption).typography(.body).foregroundStyle(Theme.textSecondary)
                        .lineLimit(2).minimumScaleFactor(0.75).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Theme.Spacing.sm)
                CardFooterTicker(sessions: data.daySessions, previousSessions: data.previousDaySessions,
                                 scores: data.scores)
            }
            .padding(Theme.Spacing.xl)
        }
        .frame(width: data.format.size.width, height: data.format.size.height)
        .clipped().background(Theme.background)
    }

    @ViewBuilder private var background: some View {
        if data.background == .photo, let image = data.session.photo {
            Image(uiImage: image).resizable().scaledToFill()
                .overlay(LinearGradient(colors: [Theme.background.opacity(0.78), Theme.background.opacity(0.28), Theme.background.opacity(0.88)], startPoint: .top, endPoint: .bottom))
        } else {
            Theme.background
            VStack { Spacer(); SkylineShape().fill(Theme.surface).frame(height: data.format.size.height * 0.28) }
        }
    }
}

#if DEBUG
#Preview("Session 4:5 dark") {
    let activityID = UUID()
    let now = Date.now
    let session = RecapSessionValue(date: now, hours: 4, activityID: activityID,
                                    activityName: "Mathematics", activityColorHex: Theme.activityColorPresets[0],
                                    note: "Problem sets and review")
    let prior = RecapSessionValue(date: now.addingTimeInterval(-86_400), hours: 3,
                                  activityID: activityID, activityName: "Mathematics",
                                  activityColorHex: Theme.activityColorPresets[0])
    SessionCard(data: SessionRecapCardData(session: session, activityHistory: [session, prior],
        allSessions: [session, prior], daySessions: [session], previousDaySessions: [prior], scores: [], caption: session.note,
        format: .portrait, background: .dark))
}
#endif
