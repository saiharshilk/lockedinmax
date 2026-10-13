import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Query private var sessions: [Session]
    @State private var range: TimeRange = .week
    @State private var mode: ChartMode = .cumulative
    @State private var selectedDate: Date?
    @State private var selectedPoint: Analytics.ChartPoint?
    @State private var scrubTrigger = 0
#if DEBUG
    @State private var showingDesign = false
#endif

    private var summary: Analytics.Summary {
        Analytics.summarize(sessions: sessions, range: range)
    }

    private var points: [Analytics.ChartPoint] {
        mode == .cumulative ? summary.cumulative : summary.buckets
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                header

                if sessions.isEmpty {
                    HomeEmptyState { appState.selectedTab = .log }
                } else {
                    HomeSummaryView(summary: summary, range: range, point: selectedPoint)
                    HomeChartView(
                        summary: summary,
                        range: range,
                        mode: mode,
                        selectedDate: $selectedDate,
                        selectedPoint: selectedPoint
                    )
                    .frame(height: 180)
                    RangePillBar(selection: Binding(
                        get: { range },
                        set: { newValue in
                            withAnimation(.easeInOut(duration: 0.2)) { range = newValue }
                        }
                    ))
                    modeToggle
                    HomePositions(positions: summary.positions)
                }
            }
            .padding(Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("")
        .toolbar {
#if DEBUG
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("DESIGN") { showingDesign = true }
                    .typography(.sectionLabel)
                    .foregroundStyle(Theme.accent)
            }
#endif
        }
#if DEBUG
        .sheet(isPresented: $showingDesign) {
            NavigationStack {
                DesignSystemPreview()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showingDesign = false }
                        }
                    }
            }
            .tint(Theme.accent)
        }
#endif
        .onChange(of: selectedDate) { _, value in updateSelection(value) }
        .onChange(of: range) { _, _ in clearSelection() }
        .onChange(of: mode) { _, _ in clearSelection() }
        .sensoryFeedback(.selection, trigger: scrubTrigger)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("LOCKEDINMAX")
                .typography(.sectionLabel)
                .foregroundStyle(Theme.accent)
            Spacer()
            Text(dateHeader)
                .typography(.sectionLabel)
                .foregroundStyle(Theme.textSecondary)
        }
        .accessibilityAddTraits(.isHeader)
    }

    private var modeToggle: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Spacer()
            ForEach(ChartMode.allCases, id: \.self) { item in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { mode = item }
                } label: {
                    Text(item.rawValue)
                        .foregroundStyle(mode == item ? Theme.accent : Theme.textSecondary)
                }
                .buttonStyle(.plain)
                if item == .cumulative {
                    Text("|").foregroundStyle(Theme.hairline)
                }
            }
        }
        .typography(.caption)
        .accessibilityLabel("Chart mode")
    }

    private var dateHeader: String {
        let date = Date.now
        let weekday = date.formatted(.dateTime.weekday(.abbreviated)).uppercased()
        let day = String(Calendar.current.component(.day, from: date))
        let month = date.formatted(.dateTime.month(.abbreviated)).uppercased()
        return "\(weekday) \(day) \(month)"
    }

    private func updateSelection(_ value: Date?) {
        guard let value else {
            selectedPoint = nil
            return
        }
        guard let nearest = points.min(by: {
            abs($0.date.timeIntervalSince(value)) < abs($1.date.timeIntervalSince(value))
        }) else {
            selectedPoint = nil
            return
        }
        if nearest.date != selectedPoint?.date || nearest.value != selectedPoint?.value {
            selectedPoint = nearest
            scrubTrigger += 1
        }
    }

    private func clearSelection() {
        selectedDate = nil
        selectedPoint = nil
    }
}

#Preview {
    NavigationStack { HomeView() }
        .modelContainer(for: [Activity.self, Session.self, Metric.self, MetricEntry.self], inMemory: true)
        .environment(AppState())
        .preferredColorScheme(.dark)
}
