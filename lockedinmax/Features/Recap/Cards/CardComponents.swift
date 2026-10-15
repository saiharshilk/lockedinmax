import SwiftUI

#if os(iOS)
import UIKit
#endif

enum RecapCardFormat: String, CaseIterable, Identifiable {
    case portrait = "4:5"
    case story = "9:16"
    var id: String { rawValue }
    var size: CGSize { self == .portrait ? CGSize(width: 360, height: 450) : CGSize(width: 360, height: 640) }
}

enum RecapCardBackground: String, CaseIterable, Identifiable {
    case dark = "DARK"
    case photo = "PHOTO"
    var id: String { rawValue }
}

struct SkylineShape: Shape {
    private let heights: [CGFloat] = [0.36, 0.58, 0.44, 0.76, 0.53, 0.67, 0.4, 0.83, 0.49, 0.62, 0.35, 0.72, 0.47, 0.89, 0.55, 0.39, 0.69, 0.46]
    private let spires: Set<Int> = [3, 7, 13, 16]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width / CGFloat(heights.count)
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        for (index, height) in heights.enumerated() {
            let left = rect.minX + CGFloat(index) * width
            let top = rect.maxY - rect.height * height
            path.addLine(to: CGPoint(x: left, y: top))
            if spires.contains(index) {
                let spireX = left + width * 0.48
                path.addLine(to: CGPoint(x: spireX, y: top - rect.height * 0.13))
                path.addLine(to: CGPoint(x: spireX + width * 0.07, y: top))
            }
            path.addLine(to: CGPoint(x: left + width, y: top))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct CardHeader: View {
    let date: Date
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
            Text("LOCKEDINMAX").typography(.sectionLabel).foregroundStyle(Theme.accent).lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: Theme.Spacing.xs)
            Text("MARKET CLOSE · \(date.formatted(.dateTime.day().month(.abbreviated)).uppercased())")
                .typography(.sectionLabel).foregroundStyle(Theme.textSecondary)
                .lineLimit(1).minimumScaleFactor(0.65).multilineTextAlignment(.trailing)
        }
    }
}

struct CardFooterTicker: View {
    let sessions: [Session]
    let previousSessions: [Session]
    let scores: [MetricEntry]

    private var activities: [(name: String, hours: Double, previous: Double)] {
        let totals = Dictionary(grouping: sessions.compactMap { session -> (Activity, Double)? in
            guard let activity = session.activity else { return nil }
            return (activity, session.hours)
        }, by: { $0.0.id })
        return totals.values.compactMap { values in
            guard let activity = values.first?.0 else { return nil }
            let prior = previousSessions.filter { $0.activity?.id == activity.id }.reduce(0) { $0 + $1.hours }
            return (activity.name, values.reduce(0) { $0 + $1.1 }, prior)
        }.sorted { $0.hours > $1.hours }.prefix(3).map { $0 }
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            ForEach(Array(activities.enumerated()), id: \.offset) { _, item in
                HStack(spacing: Theme.Spacing.xs) {
                    Text(item.name.uppercased()).foregroundStyle(Theme.textSecondary)
                    Text(item.hours >= item.previous ? "▲" : "▼").foregroundStyle(item.hours >= item.previous ? Theme.up : Theme.down)
                    Text("\(Formatters.hoursValue(item.hours))h").foregroundStyle(Theme.textPrimary)
                }
            }
            ForEach(scores.sorted { $0.date > $1.date }.prefix(2)) { entry in
                HStack(spacing: Theme.Spacing.xs) {
                    Text((entry.metric?.name ?? "SCORE").uppercased()).foregroundStyle(Theme.textSecondary)
                    Text(Formatters.metricValue(entry.value)).foregroundStyle(Theme.textPrimary)
                }
            }
        }
        .typography(.sectionLabel)
        .lineLimit(1).minimumScaleFactor(0.6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Theme.Spacing.sm)
        .overlay(alignment: .top) { Theme.hairline.frame(height: Theme.borderWidth) }
    }
}

#if DEBUG
#Preview("Card pieces") {
    VStack(spacing: Theme.Spacing.lg) {
        CardHeader(date: .now)
        SkylineShape().fill(Theme.surface).frame(height: 100)
    }.padding().background(Theme.background).preferredColorScheme(.dark)
}
#endif
