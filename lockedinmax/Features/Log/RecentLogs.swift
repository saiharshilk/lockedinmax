import SwiftData
import SwiftUI

struct RecentLogs: View {
    @Environment(\.modelContext) private var context
    @Query private var sessions: [Session]
    @Query private var entries: [MetricEntry]
    @State private var errorMessage: String?

    init() {
        var sessionFetch = FetchDescriptor<Session>(sortBy: [SortDescriptor(\Session.date, order: .reverse)])
        sessionFetch.fetchLimit = 10
        _sessions = Query(sessionFetch)
        var entryFetch = FetchDescriptor<MetricEntry>(sortBy: [SortDescriptor(\MetricEntry.date, order: .reverse)])
        entryFetch.fetchLimit = 10
        _entries = Query(entryFetch)
    }

    private var records: [Record] {
        let sessionRecords = sessions.map { Record.session($0.id, $0.date, $0.hours,
            $0.activity?.name ?? "Deleted position", $0.activity?.iconName ?? "clock",
            $0.activity?.colorHex ?? Theme.activityColorPresets[0]) }
        let entryRecords = entries.map { Record.entry($0.id, $0.date, $0.value,
            $0.metric?.name ?? "Deleted metric", $0.metric?.unit ?? "") }
        return (sessionRecords + entryRecords).sorted { $0.date > $1.date }.prefix(10).map { $0 }
    }

    var body: some View {
        Group {
            if records.isEmpty {
                Text("Your next investment starts here.")
                    .typography(.caption).foregroundStyle(Theme.textSecondary)
                    .padding(.vertical, Theme.Spacing.md)
            }
            ForEach(records.filter { exists($0) }) { record in
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: icon(for: record)).foregroundStyle(color(for: record))
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(name(for: record)).typography(.rowTitle).foregroundStyle(Theme.textPrimary)
                        Text(date(for: record), format: .dateTime.month(.abbreviated).day().hour().minute())
                            .typography(.caption).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer(minLength: Theme.Spacing.sm)
                    Text(amount(for: record)).typography(.rowTitle).foregroundStyle(Theme.textPrimary)
                }
                .padding(.vertical, Theme.Spacing.sm)
                .swipeActions {
                    Button("Delete", role: .destructive) { delete(record) }.tint(Theme.down)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .alert("Could not delete", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
    }

    private func delete(_ record: Record) {
        switch record {
        case .session(let id, _, _, _, _, _):
            if let session = sessions.first(where: { $0.id == id }) { context.delete(session) }
        case .entry(let id, _, _, _, _):
            if let entry = entries.first(where: { $0.id == id }) { context.delete(entry) }
        }
        do { try context.save() } catch {
            context.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private enum Record: Identifiable {
        case session(UUID, Date, Double, String, String, String)
        case entry(UUID, Date, Double, String, String)
        var id: UUID {
            switch self {
            case .session(let id, _, _, _, _, _), .entry(let id, _, _, _, _): id
            }
        }
        var date: Date {
            switch self {
            case .session(_, let date, _, _, _, _), .entry(_, let date, _, _, _): date
            }
        }
    }

    private func exists(_ record: Record) -> Bool {
        switch record {
        case .session(let id, _, _, _, _, _): sessions.contains { $0.id == id }
        case .entry(let id, _, _, _, _): entries.contains { $0.id == id }
        }
    }

    private func date(for record: Record) -> Date {
        record.date
    }

    private func name(for record: Record) -> String {
        switch record {
        case .session(_, _, _, let name, _, _): name
        case .entry(_, _, _, let name, _): name
        }
    }

    private func icon(for record: Record) -> String {
        switch record {
        case .session(_, _, _, _, let icon, _): icon
        case .entry: "chart.xyaxis.line"
        }
    }

    private func color(for record: Record) -> Color {
        switch record {
        case .session(_, _, _, _, _, let colorHex): Theme.activityColor(colorHex)
        case .entry: Theme.textTertiary
        }
    }

    private func amount(for record: Record) -> String {
        switch record {
        case .session(_, _, let hours, _, _, _): Formatters.hours(hours)
        case .entry(_, _, let value, _, let unit): Formatters.metric(value, unit: unit)
        }
    }
}

#Preview {
    List { RecentLogs() }
        .noScrollEdgeEffect()
        .modelContainer(for: [Activity.self, Session.self, Metric.self, MetricEntry.self], inMemory: true)
        .preferredColorScheme(.dark)
}
