import SwiftData
import SwiftUI

struct MetricDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    let metricID: UUID
    @Query private var metrics: [Metric]
    @Query private var allEntries: [MetricEntry]
    private var metric: Metric? { metrics.first { $0.id == metricID } }
    @State private var range: TimeRange = .month
    @State private var activeSheet: MetricSheet?
    @State private var photoData: Data?
    @State private var confirmingDelete = false
    @State private var errorMessage: String?

    private var entries: [MetricEntry] { allEntries.filter { $0.metric?.id == metricID }.sorted { $0.date > $1.date } }
    private var summary: StatsAnalytics.MetricSummary {
        StatsAnalytics.metricSummary(entries: entries, range: range, now: .now)
    }

    var body: some View {
        Group {
#if DEBUG
            if DebugWorkState.isSeeding {
                ProgressView("Loading sample data...").tint(Theme.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if metric != nil {
                metricContent
            } else {
                ContentUnavailableView("Metric deleted", systemImage: "trash").task { dismiss() }
            }
#else
            if metric != nil { metricContent }
            else { ContentUnavailableView("Metric deleted", systemImage: "trash").task { dismiss() } }
#endif
        }
        .background(Theme.background)
        .tabBarClearance()
        .navigationBarBackButtonHidden()
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left").foregroundStyle(Theme.accent)
                        .frame(width: Theme.minimumTapHeight, height: Theme.minimumTapHeight)
                        .contentShape(Rectangle())
                }
                    .accessibilityLabel("Back")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Edit metric", systemImage: "pencil") { activeSheet = .metric }
                    Button("Delete metric", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                } label: {
                    Image(systemName: "ellipsis").foregroundStyle(Theme.accent)
                        .frame(width: Theme.minimumTapHeight, height: Theme.minimumTapHeight)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Metric options")
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .metric:
                if let metric { MetricEditSheet(metricID: metric.id, name: metric.name, unit: metric.unit) }
                else { EmptyView() }
            case .entry(let id):
                if let entry = entries.first(where: { $0.id == id }) {
                    MetricEntryEditSheet(entryID: entry.id, value: entry.value, date: entry.date,
                                         screenshotData: entry.screenshotData)
                }
                else { EmptyView() }
            }
        }
        .fullScreenCover(isPresented: Binding(get: { photoData != nil }, set: { if !$0 { photoData = nil } })) {
            if let photoData { SessionPhotoViewer(data: photoData) { self.photoData = nil } }
        }
        .confirmationDialog("Delete \(metric?.name ?? "metric")?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete metric and \(entries.count) entries", role: .destructive, action: deleteMetric)
            Button("Cancel", role: .cancel) {}
        } message: { Text("This permanently deletes the metric and all its entries.") }
        .alert("Could not save changes", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
        .tint(Theme.accent)
#if DEBUG
        .onChange(of: appState.sampleDataRefreshVersion) { _, _ in
            if metric == nil { dismiss() }
        }
#endif
        .onChange(of: metrics.map(\.id)) { _, ids in
            if !ids.contains(metricID) { dismiss() }
        }
    }

    private var metricContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                header
                if entries.isEmpty {
                    EmptyStateView(title: "No entries yet.", message: "", buttonTitle: "") {}
                } else {
                    if let metric { MetricChartCard(metric: metric, entries: entries, range: $range) }
                    statsGrid
                    SectionHeader(title: "HISTORY")
                    ForEach(entries) { entry in
                        MetricEntryRow(entry: entry, unit: metric?.unit ?? "",
                                       onEdit: { activeSheet = .entry(entry.id) },
                                       onPhoto: { photoData = entry.screenshotData })
                            .swipeActions {
                                Button("Delete", role: .destructive) { delete(entry) }.tint(Theme.down)
                            }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.lg).padding(.bottom, Theme.Spacing.xxl)
        }
        .scrollIndicators(.hidden)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(metric?.name ?? "Deleted metric").typography(.title).foregroundStyle(Theme.textPrimary)
            Text("SCORE").typography(.sectionLabel).foregroundStyle(Theme.textTertiary)
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.md) {
            stat("LATEST", summary.latest.map { Formatters.metric($0.value, unit: metric?.unit ?? "") } ?? "—")
            stat("BEST", summary.best.map { Formatters.metric($0, unit: metric?.unit ?? "") } ?? "—")
            stat("AVERAGE", summary.entries.isEmpty ? "—" : Formatters.metric(summary.average, unit: metric?.unit ?? ""))
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
        if case .entry(let id) = activeSheet, id == entry.id { activeSheet = nil }
        context.delete(entry)
        saveContext()
    }
    private func deleteMetric() {
        guard let metric else { dismiss(); return }
        activeSheet = nil
        confirmingDelete = false
        context.delete(metric)
        do { try context.save(); dismiss() } catch { context.rollback(); errorMessage = error.localizedDescription }
    }
    private func saveContext() {
        do { try context.save() } catch { context.rollback(); errorMessage = error.localizedDescription }
    }

    private enum MetricSheet: Identifiable {
        case metric, entry(UUID)
        var id: String { switch self { case .metric: "metric"; case .entry(let id): id.uuidString } }
    }
}

#Preview {
    NavigationStack { MetricDetailView(metricID: UUID()) }
        .modelContainer(for: [Activity.self, Session.self, Metric.self, MetricEntry.self], inMemory: true)
        .preferredColorScheme(.dark)
}
