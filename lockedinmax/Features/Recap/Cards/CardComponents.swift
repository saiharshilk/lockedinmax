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
    case neon = "NEON"
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
    let title: String

    init(title: String) { self.title = title }

    init(title: String, date: Date) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d MMM"
        self.title = "\(title) · \(formatter.string(from: date).uppercased())"
    }

    var body: some View {
        Text(title).typography(.sectionLabel).foregroundStyle(Theme.textSecondary)
            .lineLimit(1).minimumScaleFactor(0.65).frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CardFooterTicker: View {
    let sessions: [RecapSessionValue]
    let previousSessions: [RecapSessionValue]
    let scores: [RecapScoreValue]

    private var activities: [(name: String, hours: Double, previous: Double)] {
        var grouped: [UUID: [RecapSessionValue]] = [:]
        for session in sessions where session.hours.isFinite {
            guard let id = session.activityID else { continue }
            grouped[id, default: []].append(session)
        }
        return grouped.values.compactMap { values in
            guard let activity = values.first else { return nil }
            let prior = previousSessions.filter { $0.activityID == activity.activityID }
                .reduce(0) { $0 + Analytics.boundedHours($1.hours) }
            return (activity.activityName, values.reduce(0) { $0 + Analytics.boundedHours($1.hours) }, prior)
        }.sorted { $0.hours > $1.hours }.prefix(4).map { $0 }
    }

    private var tickerItems: [TickerItem] {
        let positionItems = activities.map { TickerItem(name: $0.name, value: "\(compactHours($0.hours))h", isActivity: true) }
        let scoreItems = scores.sorted { $0.date > $1.date }.map {
            TickerItem(name: $0.metricName, value: Formatters.metricValue($0.value), isActivity: false)
        }
        let items = positionItems + scoreItems
        return Array(items.prefix(4))
    }

    private func activityForTickerItem(at index: Int) -> (name: String, hours: Double, previous: Double)? {
        guard tickerItems[index].isActivity else { return nil }
        let activityIndex = tickerItems.prefix(index).filter(\.isActivity).count
        return activities.indices.contains(activityIndex) ? activities[activityIndex] : nil
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            ForEach(Array(tickerItems.enumerated()), id: \.offset) { index, item in
            HStack(spacing: Theme.Spacing.xs) {
                Text(activityAbbreviation(item.name)).foregroundStyle(Theme.textSecondary)
                if let activity = activityForTickerItem(at: index) {
                    if abs(activity.hours - activity.previous) < 0.005 {
                        Text("0.0 hrs").foregroundStyle(Theme.textSecondary)
                    } else {
                        Text(activity.hours > activity.previous ? "▲" : "▼")
                            .foregroundStyle(activity.hours > activity.previous ? Theme.up : Theme.down)
                        Text(item.value).foregroundStyle(Theme.textPrimary)
                    }
                } else {
                    Text(item.value).foregroundStyle(Theme.textPrimary)
                }
            }
                .fixedSize()
            }
            let extraCount = max(0, uniqueActivityCount + scores.count - tickerItems.count)
            if extraCount > 0 {
                Text("+\(extraCount)").foregroundStyle(Theme.textSecondary).fixedSize()
            }
        }
        .typography(.caption)
        .lineLimit(1).minimumScaleFactor(0.7)
        .accessibilityElement(children: .combine)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Theme.Spacing.sm)
        .overlay(alignment: .top) { Theme.hairline.frame(height: Theme.borderWidth) }
    }

    private var uniqueActivityCount: Int { Set(sessions.compactMap(\.activityID)).count }
}

private struct TickerItem {
    let name: String
    let value: String
    let isActivity: Bool
}

private func activityAbbreviation(_ name: String) -> String {
    String(name.uppercased().filter(\.isLetter).prefix(4))
}

private func compactHours(_ value: Double) -> String {
    Formatters.hoursValue(value)
}

struct RecapCardBackdrop: View {
    let background: RecapCardBackground
    let format: RecapCardFormat
    var photo: UIImage? = nil

    var body: some View {
        Group {
            if background == .photo, let photo {
                Image(uiImage: photo).resizable().scaledToFill()
                    .overlay(LinearGradient(stops: [
                        .init(color: Theme.background.opacity(0.96), location: 0),
                        .init(color: Theme.background.opacity(0.55), location: 0.18),
                        .init(color: Theme.background.opacity(0.3), location: 0.5),
                        .init(color: Theme.background.opacity(0.62), location: 0.82),
                        .init(color: Theme.background.opacity(0.98), location: 1)
                    ], startPoint: .top, endPoint: .bottom))
            } else if background == .neon {
                Theme.accent
                VStack { Spacer(); SkylineShape().fill(Theme.background.opacity(0.12))
                    .frame(height: format.size.height * 0.26) }
            } else {
                Theme.background
                VStack { Spacer(); SkylineShape().fill(Theme.surface)
                    .frame(height: format.size.height * 0.26) }
            }
        }
        .frame(width: format.size.width, height: format.size.height)
        .clipped()
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("Card pieces") {
    VStack(spacing: Theme.Spacing.lg) {
        CardHeader(title: "MARKET CLOSE", date: .now)
        SkylineShape().fill(Theme.surface).frame(height: 100)
    }.padding().background(Theme.background).preferredColorScheme(.dark)
}
#endif
