import SwiftData
import SwiftUI

struct ActivityDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    let activityID: UUID
    @Query private var activities: [Activity]
    private var activity: Activity? { activities.first { $0.id == activityID } }

    @State private var range: TimeRange = .week
    @State private var mode: ChartMode = .cumulative
    @State private var activeSheet: ActivityDetailSheet?
    @State private var photoData: Data?
    @State private var confirmingDelete = false
    @State private var errorMessage: String?

    @Query private var allSessions: [Session]

    private var sessions: [Session] {
        allSessions.filter { $0.activity?.id == activityID }.sorted { $0.date > $1.date }
    }
    private var dayGroups: [ActivityDayGroup] {
        let grouped = Dictionary(grouping: sessions) { Calendar.current.startOfDay(for: $0.date) }
        return grouped.map { date, values in
            ActivityDayGroup(date: date, sessions: values.sorted { $0.date > $1.date })
        }.sorted { $0.date > $1.date }
    }

    var body: some View {
        Group {
#if DEBUG
            if DebugWorkState.isSeeding {
                ProgressView("Loading sample data...").tint(Theme.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.background)
            } else if activity != nil {
                activityContent
            } else {
                ContentUnavailableView("Position deleted", systemImage: "trash")
                    .task { dismiss() }
            }
#else
            if activity != nil { activityContent }
            else { ContentUnavailableView("Position deleted", systemImage: "trash").task { dismiss() } }
#endif
        }
#if DEBUG
        .onChange(of: appState.sampleDataRefreshVersion) { _, _ in
            if activity == nil { dismiss() }
        }
#endif
        .onChange(of: activities.map(\.id)) { _, ids in
            if !ids.contains(activityID) { dismiss() }
        }
    }

    private var activityContent: some View {
        List {
            header
            if sessions.isEmpty {
                emptyState
            } else {
                chartCard
                stats
                SectionHeader(title: "SESSIONS")
                    .listRowBackground(Theme.background)
                ForEach(dayGroups) { group in
                    Section {
                        ForEach(group.sessions) { session in
                            ActivitySessionRow(session: session,
                                               onEdit: { activeSheet = .session(session.id) },
                                               onPhoto: { photoData = session.photoData })
                                .listRowBackground(Theme.background)
                                .swipeActions(edge: .leading) {
                                    Button("Share recap", systemImage: "square.and.arrow.up") {
                                        appState.sessionRecapID = session.id
                                        appState.selectedTab = .recap
                                    }.tint(Theme.accent)
                                }
                                .swipeActions {
                                    Button("Delete", role: .destructive) { delete(session) }
                                        .tint(Theme.down)
                                }
                        }
                    } header: {
                        dayHeader(group)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .tabBarClearance()
        .background(Theme.background)
        .listRowSeparator(.hidden)
        .navigationBarBackButtonHidden()
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
                    Button("Edit activity", systemImage: "pencil") { activeSheet = .activity }
                    Button("Delete activity", systemImage: "trash", role: .destructive) {
                        confirmingDelete = true
                    }
                } label: {
                    Image(systemName: "ellipsis").foregroundStyle(Theme.accent)
                        .frame(width: Theme.minimumTapHeight, height: Theme.minimumTapHeight)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Activity options")
            }
        }
        .tint(Theme.accent)
        .toolbar(.visible, for: .navigationBar)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .activity:
                if let activity { NewActivitySheet(activity: activity) { _ in } }
                else { EmptyView() }
            case .session(let id):
                if let session = sessions.first(where: { $0.id == id }) {
                    SessionEditSheet(sessionID: session.id, hours: session.hours, date: session.date,
                                     note: session.note, photoData: session.photoData)
                }
                else { EmptyView() }
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { photoData != nil }, set: { if !$0 { photoData = nil } }
        )) {
            if let photoData { SessionPhotoViewer(data: photoData) { self.photoData = nil } }
        }
        .confirmationDialog("Delete \(activity?.name ?? "position")?", isPresented: $confirmingDelete,
                            titleVisibility: .visible) {
            Button("Delete \(sessions.count) sessions", role: .destructive, action: deleteActivity)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete the position and its \(sessions.count) sessions.")
        }
        .alert("Could not save changes", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                Circle().fill(Theme.activityColor(activity?.colorHex ?? Theme.activityColorPresets[0])).frame(width: 52, height: 52)
                Image(systemName: activity?.iconName ?? "clock").typography(.title).foregroundStyle(Theme.onAccent)
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(activity?.name ?? "Deleted position").typography(.title).foregroundStyle(Theme.textPrimary)
                Text("POSITION").typography(.sectionLabel).foregroundStyle(Theme.textTertiary)
            }
            Spacer()
        }
        .padding(.vertical, Theme.Spacing.md)
        .listRowBackground(Theme.background)
    }

    private var chartCard: some View {
        TimeSeriesChartCard(sessions: sessions, label: activity?.name ?? "Position", range: $range, mode: $mode)
            .padding(.vertical, Theme.Spacing.md)
            .listRowBackground(Theme.background)
    }

    private var stats: some View {
        ActivityStatsGrid(sessions: sessions)
            .padding(.vertical, Theme.Spacing.md)
            .listRowBackground(Theme.background)
    }

    private func dayHeader(_ group: ActivityDayGroup) -> some View {
        HStack {
            Text(group.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)).uppercased())
            Spacer()
            Text(Formatters.hours(group.sessions.reduce(0) { $0 + Analytics.boundedHours($1.hours) }))
        }
        .typography(.sectionLabel)
        .foregroundStyle(Theme.textTertiary)
        .textCase(nil)
        .padding(.top, Theme.Spacing.sm)
        .listRowBackground(Theme.background)
    }

    private var emptyState: some View {
        EmptyStateView(title: "No sessions yet.", message: "", buttonTitle: "LOG A SESSION") {
            appState.sessionActivityID = activityID
            appState.selectedTab = .log
        }
        .listRowBackground(Theme.background)
    }

    private func delete(_ session: Session) {
        if case .session(let id) = activeSheet, id == session.id { activeSheet = nil }
        if appState.sessionRecapID == session.id { appState.sessionRecapID = nil }
        context.delete(session)
        saveContext()
    }

    private func deleteActivity() {
        guard let activity else { dismiss(); return }
        activeSheet = nil
        photoData = nil
        confirmingDelete = false
        context.delete(activity)
        do {
            try context.save()
            dismiss()
        } catch {
            context.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func saveContext() {
        do { try context.save() }
        catch { context.rollback(); errorMessage = error.localizedDescription }
    }

    private enum ActivityDetailSheet: Identifiable {
        case activity
        case session(UUID)
        var id: String {
            switch self {
            case .activity: "activity"
            case .session(let id): id.uuidString
            }
        }
    }

    private struct ActivityDayGroup: Identifiable {
        let date: Date
        let sessions: [Session]
        var id: Date { date }
    }
}

#Preview {
    NavigationStack { ActivityDetailView(activityID: UUID()) }
        .modelContainer(for: [Activity.self, Session.self, Metric.self, MetricEntry.self], inMemory: true)
        .environment(AppState()).preferredColorScheme(.dark)
}
