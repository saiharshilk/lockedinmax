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
        (sessions.map(Record.session) + entries.map(Record.entry))
            .sorted { $0.date > $1.date }.prefix(10).map { $0 }
    }

    var body: some View {
        Group {
            if records.isEmpty {
                Text("Your next investment starts here.")
                    .typography(.caption).foregroundStyle(Theme.textSecondary)
                    .padding(.vertical, Theme.Spacing.md)
            }
            ForEach(records) { record in
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: record.icon).foregroundStyle(record.color)
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(record.name).typography(.rowTitle).foregroundStyle(Theme.textPrimary)
                        Text(record.date, format: .dateTime.month(.abbreviated).day().hour().minute())
                            .typography(.caption).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer(minLength: Theme.Spacing.sm)
                    Text(record.amount).typography(.rowTitle).foregroundStyle(Theme.textPrimary)
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
        case .session(let session): context.delete(session)
        case .entry(let entry): context.delete(entry)
        }
        do { try context.save() } catch {
            context.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private enum Record: Identifiable {
        case session(Session), entry(MetricEntry)
        var id: UUID {
            switch self { case .session(let s): s.id; case .entry(let e): e.id }
        }
        var date: Date {
            switch self { case .session(let s): s.date; case .entry(let e): e.date }
        }
        var name: String {
            switch self {
            case .session(let s): s.activity?.name ?? "Deleted position"
            case .entry(let e): e.metric?.name ?? "Deleted metric"
            }
        }
        var icon: String {
            switch self {
            case .session(let s): s.activity?.iconName ?? "clock"
            case .entry: "chart.xyaxis.line"
            }
        }
        var color: Color {
            switch self {
            case .session(let s): Theme.activityColor(s.activity?.colorHex ?? Theme.activityColorPresets[0])
            case .entry: Theme.textTertiary
            }
        }
        var amount: String {
            switch self {
            case .session(let s): "\(s.hours.formatted(.number.precision(.fractionLength(0...2)))) hrs"
            case .entry(let e):
                e.value.formatted(.number.precision(.fractionLength(0...2)))
                    + (e.metric?.unit.isEmpty == false ? " \(e.metric?.unit ?? "")" : "")
            }
        }
    }
}

#Preview {
    List { RecentLogs() }
        .modelContainer(for: [Activity.self, Session.self, Metric.self, MetricEntry.self], inMemory: true)
        .preferredColorScheme(.dark)
}
