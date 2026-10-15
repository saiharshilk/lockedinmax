import SwiftData
import SwiftUI

struct MetricDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let metric: Metric
    @Query private var allEntries: [MetricEntry]
    @State private var range: TimeRange = .month
    @State private var activeSheet: MetricSheet?
    @State private var photoData: Data?
    @State private var confirmingDelete = false
    @State private var errorMessage: String?

    private var entries: [MetricEntry] { allEntries.filter { $0.metric?.id == metric.id }.sorted { $0.date > $1.date } }
    private var summary: StatsAnalytics.MetricSummary {
        StatsAnalytics.metricSummary(entries: entries, range: range, now: .now)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                header
                if entries.isEmpty {
                    Text("No entries yet.").typography(.body).foregroundStyle(Theme.textSecondary)
                        .padding(.vertical, Theme.Spacing.xl)
                } else {
                    MetricChartCard(metric: metric, entries: entries, range: $range)
                    statsGrid
                    SectionHeader(title: "HISTORY")
                    ForEach(entries) { entry in
                        MetricEntryRow(entry: entry, unit: metric.unit,
                                       onEdit: { activeSheet = .entry(entry) },
                                       onPhoto: { photoData = entry.screenshotData })
                            .swipeActions {
                                Button("Delete", role: .destructive) { delete(entry) }.tint(Theme.down)
                            }
                    }
                }
            }.padding(Theme.Spacing.lg).padding(.bottom, Theme.Spacing.xxl)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: { Image(systemName: "chevron.left").foregroundStyle(Theme.accent) }
                    .accessibilityLabel("Back")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Edit metric", systemImage: "pencil") { activeSheet = .metric }
                    Button("Delete metric", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                } label: { Image(systemName: "ellipsis").foregroundStyle(Theme.accent) }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .metric: MetricEditSheet(metric: metric)
            case .entry(let entry): MetricEntryEditSheet(entry: entry)
            }
        }
        .fullScreenCover(isPresented: Binding(get: { photoData != nil }, set: { if !$0 { photoData = nil } })) {
            if let photoData { SessionPhotoViewer(data: photoData) { self.photoData = nil } }
        }
        .confirmationDialog("Delete \(metric.name)?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete metric and \(entries.count) entries", role: .destructive, action: deleteMetric)
            Button("Cancel", role: .cancel) {}
        } message: { Text("This permanently deletes the metric and all its entries.") }
        .alert("Could not save changes", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
        .tint(Theme.accent)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(metric.name).typography(.title).foregroundStyle(Theme.textPrimary)
            Text("SCORE").typography(.sectionLabel).foregroundStyle(Theme.textTertiary)
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.md) {
            stat("LATEST", summary.latest.map { Formatters.metric($0.value, unit: metric.unit) } ?? "—")
            stat("BEST", summary.best.map { Formatters.metric($0, unit: metric.unit) } ?? "—")
            stat("AVERAGE", summary.entries.isEmpty ? "—" : Formatters.metric(summary.average, unit: metric.unit))
            stat("ENTRIES", "\(summary.entries.count)")
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title).typography(.sectionLabel).foregroundStyle(Theme.textTertiary)
            Text(value).typography(.rowTitle).foregroundStyle(Theme.textPrimary).lineLimit(1).minimumScaleFactor(0.7)
        }.frame(maxWidth: .infinity, minHeight: 54, alignment: .leading).padding(Theme.Spacing.md).surfaceCard()
    }

    private func delete(_ entry: MetricEntry) {
        context.delete(entry)
        saveContext()
    }
    private func deleteMetric() {
        context.delete(metric)
        do { try context.save(); dismiss() } catch { context.rollback(); errorMessage = error.localizedDescription }
    }
    private func saveContext() {
        do { try context.save() } catch { context.rollback(); errorMessage = error.localizedDescription }
    }

    private enum MetricSheet: Identifiable {
        case metric, entry(MetricEntry)
        var id: String { switch self { case .metric: "metric"; case .entry(let entry): entry.id.uuidString } }
    }
}

#Preview {
    NavigationStack { MetricDetailView(metric: Metric(name: "Sleep Score", unit: "pts")) }
        .modelContainer(for: [Activity.self, Session.self, Metric.self, MetricEntry.self], inMemory: true)
        .preferredColorScheme(.dark)
}
