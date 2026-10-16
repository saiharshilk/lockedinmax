#if DEBUG
import Foundation
import SwiftData

struct AnalyticsSweepResult: CustomStringConvertible {
    let passed: Bool
    let callCount: Int
    let slowest: [(name: String, milliseconds: Double)]
    let loopMessages: [String]

    var description: String {
        let status = passed ? "PASS" : "FAIL"
        let slowText = slowest.map { "\($0.name)=\(String(format: "%.1f", $0.milliseconds))ms" }
            .joined(separator: ", ")
        let loops = loopMessages.isEmpty ? "none" : loopMessages.joined(separator: " | ")
        return "\(status): \(callCount) calls; slowest: \(slowText); loop guards: \(loops)"
    }
}

enum AnalyticsSweep {
    @MainActor
    static func runAnalyticsSweep(now: Date = .now) -> AnalyticsSweepResult {
        LoopGuard.resetMessages()
        var calls: [(String, Double)] = []
        func measure(_ name: String, _ operation: () -> Void) {
            let start = ProcessInfo.processInfo.systemUptime
            operation()
            calls.append((name, (ProcessInfo.processInfo.systemUptime - start) * 1_000))
        }

        let schema = Schema([Activity.self, Session.self, Metric.self, MetricEntry.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)
            context.autosaveEnabled = false
            _ = try SampleData.load(into: context, now: now)
            let sessions = try context.fetch(FetchDescriptor<Session>())
            let activities = try context.fetch(FetchDescriptor<Activity>())
            let metrics = try context.fetch(FetchDescriptor<Metric>())
            let entries = try context.fetch(FetchDescriptor<MetricEntry>())
            let calendar = Calendar.current

            for range in TimeRange.allCases {
                measure("Home \(range.rawValue) cumulative") {
                    _ = Analytics.summarize(sessions: sessions, range: range, now: now, calendar: calendar).cumulative
                }
                measure("Home \(range.rawValue) per-day") {
                    _ = Analytics.summarize(sessions: sessions, range: range, now: now, calendar: calendar).buckets
                }
                for activity in activities {
                    measure("Activity \(activity.name) \(range.rawValue) totals/deltas") {
                        _ = Analytics.activitySummary(sessions: sessions, activityID: activity.id,
                                                      range: range, now: now, calendar: calendar)
                    }
                }
            }

            for activity in activities {
                let activitySessions = sessions.filter { $0.activity?.id == activity.id }
                measure("ActivityStats \(activity.name)") {
                    _ = ActivityStats.calculate(sessions: activitySessions, now: now, calendar: calendar)
                }
            }

            let periodKinds: [(StatsPeriodKind, Calendar.Component)] = [(.day, .day), (.week, .weekOfYear), (.month, .month)]
            for (kind, component) in periodKinds {
                let current = StatsAnalytics.period(kind: kind, anchor: now, calendar: calendar)
                for offset in 0...6 {
                    let anchor = calendar.date(byAdding: component, value: -offset, to: current.start) ?? current.start
                    measure("Stats \(kind.rawValue) period -\(offset) summary/breakdown/insights") {
                        _ = StatsAnalytics.summarize(sessions: sessions, kind: kind, anchor: anchor,
                                                      now: now, calendar: calendar)
                    }
                }
            }
            measure("12-week heatmap") {
                _ = StatsAnalytics.heatmap(sessions: sessions, today: now, calendar: calendar)
            }

            for metric in metrics {
                let metricEntries = entries.filter { $0.metric?.id == metric.id }
                for range in TimeRange.allCases {
                    measure("Metric \(metric.name) \(range.rawValue)") {
                        _ = StatsAnalytics.metricSummary(entries: metricEntries, range: range,
                                                         now: now, calendar: calendar)
                    }
                }
            }

            if let session = sessions.max(by: { $0.date < $1.date }) {
                measure("Recap session card-data builder") {
                    _ = RecapCardFactory.session(session, allSessions: sessions, scores: entries,
                                                 caption: session.note, format: .portrait, background: .dark)
                }
            }
            measure("Recap Market Close card-data builder") {
                _ = RecapCardFactory.marketClose(calendar.startOfDay(for: now), sessions: sessions,
                                                  scores: entries, format: .portrait)
            }
        } catch {
            calls.append(("Sweep setup: \(error.localizedDescription)", .infinity))
        }

        let slowest = calls.sorted { $0.1 > $1.1 }.prefix(5).map { (name: $0.0, milliseconds: $0.1) }
        let messages = LoopGuard.messages
        let passed = !calls.contains { !$0.1.isFinite || $0.1 > 250 } && messages.isEmpty
        let result = AnalyticsSweepResult(passed: passed, callCount: calls.count,
                                          slowest: slowest, loopMessages: messages)
        NSLog("[AnalyticsSweep] %@", result.description)
        return result
    }
}
#endif
