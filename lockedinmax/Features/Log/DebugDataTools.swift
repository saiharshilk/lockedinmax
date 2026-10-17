#if DEBUG
import Combine
import SwiftData
import SwiftUI
import UIKit

struct DebugDataTools: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query private var activities: [Activity]
    @Query private var sessions: [Session]
    @Query private var entries: [MetricEntry]
    @Query private var metrics: [Metric]
    @State private var confirmingClear = false
    @State private var confirmingSampleReplacement = false
    @State private var isSeeding = false
    @State private var isLoadingSamples = false
    @State private var errorMessage: String?
    @State private var selfTestResult: String?
    @State private var sampleCheckResult: String?
    @State private var sweepResult: String?
    @State private var lastLoadTimings: SampleLoadTimings?
    @State private var previousAnalytics = Analytics.debugHomeRecomputeCount
    @State private var analyticsRate = 0
    @State private var diagnosticRefresh = 0
    @State private var observedSeeding = DebugWorkState.isSeeding
    @State private var observedGeneration = DebugWorkState.generation
    @State private var isRunningChurnTest = false
    private let diagnosticTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var diagnostics: DebugDiagnostics { DebugDiagnostics.shared }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if isRunningChurnTest {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Label("Churn test running...", systemImage: "arrow.triangle.2.circlepath")
                    if let churnTestResult = appState.churnTestResult {
                        Text(churnTestResult).textSelection(.enabled)
                    }
                }.foregroundStyle(Theme.accent)
            } else if observedSeeding || DebugWorkState.isSeeding || isSeeding {
                Label("Loading sample data...", systemImage: "hourglass")
                    .foregroundStyle(Theme.accent)
                    .padding(.vertical, Theme.Spacing.md)
            } else {
                diagnosticsContent
            }
        }
        .typography(.caption).tint(Theme.accent)
        .onAppear {
            if !isSeeding && !DebugWorkState.isSeeding { diagnostics.observe(context) }
        }
        .task(id: appState.sampleDataRefreshVersion) {
            observedGeneration = DebugWorkState.generation
            observedSeeding = DebugWorkState.isSeeding
            if !observedSeeding { diagnostics.observe(context) }
        }
        .onReceive(diagnosticTimer) { _ in
            guard !DebugWorkState.isSeeding, !isSeeding else { return }
            let current = Analytics.debugHomeRecomputeCount
            analyticsRate = max(0, current - previousAnalytics)
            previousAnalytics = current
            diagnosticRefresh += 1
            observedSeeding = DebugWorkState.isSeeding
            observedGeneration = DebugWorkState.generation
        }
        .confirmationDialog("Replace existing data with sample data?", isPresented: $confirmingSampleReplacement, titleVisibility: .visible) {
            Button("Replace existing data", role: .destructive) { loadSamples(replacing: true) }
            Button("Cancel", role: .cancel) {}
        } message: { Text("All current positions, sessions, metrics, and entries will be replaced.") }
        .confirmationDialog("Clear all positions, sessions, metrics, and entries?", isPresented: $confirmingClear, titleVisibility: .visible) {
            Button("Clear all data", role: .destructive) { clearAllData() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This cannot be undone.") }
        .alert("Data operation failed", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
    }

    @ViewBuilder private var diagnosticsContent: some View {
            SectionHeader(title: "DATA DIAGNOSTICS")
            diagnostic("Sessions", "\(sessions.count)")
            diagnostic("Metric entries", "\(entries.count)")
            diagnostic("Max session hours", Formatters.hoursValue(sessions.map(\.hours).filter(\.isFinite).max() ?? 0))
            diagnostic("Total stored hours", Formatters.hours(sessions.reduce(0) { $0 + ($1.hours.isFinite ? $1.hours : 0) }))
            diagnostic("Sessions >24 or non-finite", "\(sessions.filter { !$0.hours.isFinite || $0.hours > 24 }.count)")
            diagnostic("Analytics recomputes/sec", "\(analyticsRate)")
            diagnostic("Home analytics since launch", "\(Analytics.debugHomeRecomputeCount)")
            diagnostic("Recap renders since launch", "\(diagnostics.recapRenders)")
            diagnostic("Selected tab changes", "\(diagnostics.tabChanges.count)")
            Button("SELF-TEST RECAP RENDERING") { runSelfTest() }
                .disabled(isLoadingSamples || isRunningChurnTest)
                .foregroundStyle(Theme.accent)
            Button("Churn test") { runChurnTest() }
                .disabled(isLoadingSamples || isSeeding || isRunningChurnTest)
                .foregroundStyle(Theme.accent)
            if !isRunningChurnTest, let churnTestResult = appState.churnTestResult {
                Text(churnTestResult).foregroundStyle(churnTestResult.hasPrefix("PASS") ? Theme.up : Theme.down)
                    .textSelection(.enabled)
            }
            if let selfTestResult { Text(selfTestResult).foregroundStyle(selfTestResult.hasPrefix("PASS") ? Theme.up : Theme.down) }
            Button("Check sample generator") { sampleCheckResult = SampleData.runSampleDataSelfCheck() }
                .disabled(isLoadingSamples || isRunningChurnTest)
                .foregroundStyle(Theme.accent)
            if let sampleCheckResult { Text(sampleCheckResult).foregroundStyle(sampleCheckResult.hasPrefix("PASS") ? Theme.up : Theme.down) }
            Button("Run analytics sweep") { sweepResult = AnalyticsSweep.runAnalyticsSweep().description }
                .disabled(isLoadingSamples || isRunningChurnTest)
                .foregroundStyle(Theme.accent)
            if let sweepResult { Text(sweepResult).foregroundStyle(sweepResult.hasPrefix("PASS") ? Theme.up : Theme.down) }
            if let timings = lastLoadTimings ?? DebugWorkState.lastSampleLoadTimings {
                diagnostic("Last sample load", timings.description)
            }
            Button("Delete invalid sessions") { deleteInvalidSessions() }
                .disabled(isLoadingSamples || isRunningChurnTest || !sessions.contains { !$0.hours.isFinite || $0.hours <= 0 })
                .foregroundStyle(Theme.down)
            Button("Clamp over-24 sessions to 24") { clampLongSessions() }
                .disabled(isLoadingSamples || isRunningChurnTest || !sessions.contains { $0.hours.isFinite && $0.hours > 24 })
                .foregroundStyle(Theme.down)
            Button {
                if sessions.isEmpty && entries.isEmpty && activities.isEmpty && metrics.isEmpty { loadSamples(replacing: false) }
                else { confirmingSampleReplacement = true }
            } label: {
                if isLoadingSamples { Label("Loading...", systemImage: "hourglass") }
                else { Text("Load sample data") }
            }
            .disabled(isLoadingSamples || isRunningChurnTest)
            Button("Clear all data", role: .destructive) { confirmingClear = true }
                .disabled(isLoadingSamples || isRunningChurnTest)
                .foregroundStyle(Theme.down)
            eventList(title: "MODEL SAVES", events: diagnostics.saveEvents.map(\.summary))
            eventList(title: "TAB CHANGE STACKS", events: diagnostics.tabChanges.map {
                "\($0.date.formatted(date: .omitted, time: .standard)) \($0.from)->\($0.to)\n\($0.frames.joined(separator: "\n"))"
            })
    }

    private func diagnostic(_ title: String, _ value: String) -> some View {
        HStack { Text(title).foregroundStyle(Theme.textSecondary); Spacer(); Text(value).foregroundStyle(Theme.textPrimary) }
    }

    private func eventList(title: String, events: [String]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            SectionHeader(title: title)
            ForEach(Array(events.prefix(30).enumerated()), id: \.offset) { _, event in
                Text(event).foregroundStyle(Theme.textSecondary).lineLimit(4).textSelection(.enabled)
            }
        }
    }

    private func perform(_ action: () throws -> Void) {
        do { try action() } catch { context.rollback(); errorMessage = error.localizedDescription }
    }

    private func deleteInvalidSessions() {
        repairData(mode: .invalidSessionsOnly)
    }

    private func clampLongSessions() {
        repairData(mode: .clampLongSessionsOnly)
    }

    private func repairData(mode: DebugDataOperations.RepairMode) {
        guard !isSeeding && !DebugWorkState.isSeeding else { return }
        isSeeding = true
        Task { @MainActor in
            do { try await DebugDataOperations.repairData(in: context, appState: appState, mode: mode) }
            catch { errorMessage = error.localizedDescription }
            isSeeding = false
            observedSeeding = false
            observedGeneration = DebugWorkState.generation
        }
    }

    private func loadSamples(replacing: Bool) {
        guard !isLoadingSamples, !DebugWorkState.isSeeding, !isSeeding else { return }
        isLoadingSamples = true
        isSeeding = true
        Task { @MainActor in
            do {
                let timings = try await DebugDataOperations.loadSamples(in: context, appState: appState,
                                                                       replacing: replacing)
                lastLoadTimings = timings
                NSLog("[SampleDataLoad] %@", timings.description)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoadingSamples = false
            isSeeding = false
            observedSeeding = false
            observedGeneration = DebugWorkState.generation
            diagnostics.observe(context)
        }
    }

    private func clearAllData() {
        Task { @MainActor in
            isSeeding = true
            do { try await DebugDataOperations.clearData(in: context, appState: appState) }
            catch { errorMessage = error.localizedDescription }
            isSeeding = false
            observedSeeding = false
            observedGeneration = DebugWorkState.generation
            diagnostics.observe(context)
        }
    }

    private func runChurnTest() {
        guard !isLoadingSamples, !DebugWorkState.isSeeding, !isSeeding, !isRunningChurnTest else { return }
        isRunningChurnTest = true
        isSeeding = true
        Task { @MainActor in
            let report = await DebugDataOperations.runChurnTest(in: context, appState: appState)
            sampleCheckResult = nil
            sweepResult = nil
            lastLoadTimings = DebugWorkState.lastSampleLoadTimings
            errorMessage = report.hasPrefix("FAIL") ? report : nil
            isRunningChurnTest = false
            isSeeding = false
            observedSeeding = false
            observedGeneration = DebugWorkState.generation
            diagnostics.observe(context)
        }
    }

    private func runSelfTest() {
        struct Snapshot {
            let totalHours: Double
            let totalHoursBits: UInt64
            let count: Int
            let tab: AppTab
        }
        func snapshot() throws -> Snapshot {
            let stored = try context.fetch(FetchDescriptor<Session>())
            let totalHours = stored.reduce(0) { $0 + $1.hours }
            return Snapshot(totalHours: totalHours, totalHoursBits: totalHours.bitPattern,
                            count: stored.count, tab: appState.selectedTab)
        }

        do {
            let start = try snapshot()
            let startSaves = diagnostics.saveEventCount
            let activityID = UUID()
            let photo = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 40)).image { renderer in
                renderer.cgContext.setFillColor(UIColor(Theme.surface).cgColor)
                renderer.cgContext.fill(CGRect(x: 0, y: 0, width: 32, height: 40))
            }
            let sessionValue = RecapSessionValue(date: .now, hours: 2.5, activityID: activityID,
                activityName: "Sample Activity", activityColorHex: Theme.activityColorPresets[0],
                note: "Model-free regression check", photo: photo)
            let priorValue = RecapSessionValue(date: .now.addingTimeInterval(-86_400), hours: 1.5,
                activityID: activityID, activityName: "Sample Activity",
                activityColorHex: Theme.activityColorPresets[0])
            let variants = RecapCardFormat.allCases.flatMap { format in
                RecapCardBackground.allCases.map { background in
                    (format: format, background: background, market: false)
                }
            } + RecapCardFormat.allCases.map { format in
                (format: format, background: RecapCardBackground.dark, market: true)
            }
            var failedRenders = 0
            for index in 0..<20 {
                let variant = variants[index % variants.count]
                if variant.market {
                    let data = MarketCloseCardData(date: .now, sessions: [sessionValue],
                        previousDaySessions: [priorValue], scores: [], format: variant.format)
                    if !render(MarketCloseCard(data: data), format: variant.format) { failedRenders += 1 }
                } else {
                    let data = SessionRecapCardData(session: sessionValue,
                        activityHistory: [sessionValue, priorValue], allSessions: [sessionValue],
                        daySessions: [sessionValue], previousDaySessions: [priorValue], scores: [],
                        caption: sessionValue.note, format: variant.format, background: variant.background)
                    if !render(SessionCard(data: data), format: variant.format) { failedRenders += 1 }
                }
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                do {
                    let end = try snapshot()
                    let differences = [
                        start.totalHoursBits == end.totalHoursBits ? nil : "hours \(start.totalHours) -> \(end.totalHours)",
                        start.count == end.count ? nil : "sessions \(start.count) -> \(end.count)",
                        start.tab == end.tab ? nil : "tab \(start.tab) -> \(end.tab)",
                        startSaves == diagnostics.saveEventCount ? nil : "save events \(startSaves) -> \(diagnostics.saveEventCount)",
                        failedRenders == 0 ? nil : "\(failedRenders) image renders returned nil"
                    ].compactMap { $0 }
                    selfTestResult = differences.isEmpty
                        ? "PASS: 20 model-free renders; hours, sessions, tab and saves unchanged"
                        : "FAIL: " + differences.joined(separator: "; ")
                } catch { selfTestResult = "FAIL: could not re-read sessions: \(error.localizedDescription)" }
            }
        } catch { selfTestResult = "FAIL: could not read sessions: \(error.localizedDescription)" }
    }

    @MainActor private func render<Card: View>(_ card: Card, format: RecapCardFormat) -> Bool {
        diagnostics.recordRecapRender()
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(format.size)
        return renderer.uiImage != nil
    }
}


#Preview {
    DebugDataTools().padding(Theme.Spacing.lg).background(Theme.background)
        .modelContainer(for: [Activity.self, Session.self, Metric.self, MetricEntry.self], inMemory: true)
        .environment(AppState())
}
#endif
