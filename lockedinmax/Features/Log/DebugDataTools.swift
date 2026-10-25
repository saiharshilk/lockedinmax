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
    @State private var replacementConfirmationExpiresAt: Date?
    @State private var clearConfirmationExpiresAt: Date?
    @State private var isSeeding = false
    @State private var isLoadingSamples = false
    @State private var errorMessage: String?
    @State private var selfTestResult: String?
    @State private var didRunRequestedSelfTest = false
    @State private var sampleCheckResult: String?
    @State private var sweepResult: String?
    @State private var statsSelfCheckResult: String?
    @State private var recapCardCheckResult: String?
    @State private var lastLoadTimings: SampleLoadTimings?
    @State private var sampleLoadResult: String?
    @State private var previousAnalytics = Analytics.debugHomeRecomputeCount
    @State private var analyticsRate = 0
    @State private var diagnosticRefresh = 0
    @State private var screenProbe = ScreenProbeSnapshot.capture()
    @State private var observedSeeding = DebugWorkState.isSeeding
    @State private var observedGeneration = DebugWorkState.generation
    @State private var isRunningChurnTest = false
    @State private var isRunningDebugTask = false
    @State private var currentTaskName: String?
    private let diagnosticTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var diagnostics: DebugDiagnostics { DebugDiagnostics.shared }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(appState.debugTaskRunner.status)
                .foregroundStyle(appState.debugTaskRunner.status.hasPrefix("FAILED:") ? Theme.down : Theme.accent)
                .textSelection(.enabled)
                .accessibilityIdentifier("debugTaskStatus")
            Button("Reset debug flags") {
                appState.debugTaskRunner.resetFlags()
                isLoadingSamples = false
                isSeeding = false
                observedSeeding = false
                currentTaskName = nil
                isRunningDebugTask = false
            }
            .foregroundStyle(Theme.textSecondary)
            if isRunningDebugTask || DebugWorkState.isRunningDebugTask {
                Label("Running... \(currentTaskName ?? "")", systemImage: "arrow.triangle.2.circlepath")
                    .foregroundStyle(Theme.accent).padding(.vertical, Theme.Spacing.md)
            }
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
                diagnosticsContent
            } else {
                diagnosticsContent
            }

        }
        .typography(.caption).tint(Theme.accent)
        .onAppear {
            if !isSeeding && !DebugWorkState.isSeeding { diagnostics.observe(context) }
        }
        .task {
            guard ProcessInfo.processInfo.arguments.contains("--recap-self-test"), !didRunRequestedSelfTest else { return }
            didRunRequestedSelfTest = true
            runSelfTest()
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
        .alert("Data operation failed", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
    }

    @ViewBuilder private var diagnosticsContent: some View {
            SectionHeader(title: "SCREEN PROBE")
            Button("Refresh screen probe") { screenProbe = ScreenProbeSnapshot.capture() }
                .foregroundStyle(Theme.accent)
            probeValue("UIScreen bounds", screenProbe.screenBounds)
            probeValue("Key window bounds", screenProbe.windowBounds)
            HStack {
                Text("Window safeAreaInsets").foregroundStyle(Theme.textSecondary)
                Spacer(minLength: Theme.Spacing.sm)
                Text(screenProbe.safeAreaDescription).foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.trailing).textSelection(.enabled)
            }
            probeValue("Root view frame", screenProbe.rootFrame)
            probeValue("Tab bar container frame", screenProbe.tabContainerFrame)
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
                .disabled(isRunningDebugTask || isLoadingSamples || isRunningChurnTest)
                .foregroundStyle(Theme.accent)
            Button("Churn test") { runChurnTest() }
                .disabled(isRunningDebugTask || isLoadingSamples || isSeeding || isRunningChurnTest)
                .foregroundStyle(Theme.accent)
            if !isRunningChurnTest, let churnTestResult = appState.churnTestResult {
                Text(churnTestResult).foregroundStyle(churnTestResult.hasPrefix("PASS") ? Theme.up : Theme.down)
                    .textSelection(.enabled)
            }
            if let selfTestResult { Text(selfTestResult).foregroundStyle(selfTestResult.hasPrefix("PASS") ? Theme.up : Theme.down) }
            Button("Check sample generator") { runSynchronousTask("sample check") { sampleCheckResult = SampleData.runSampleDataSelfCheck() } }
                .disabled(isRunningDebugTask || isLoadingSamples || isRunningChurnTest)
                .foregroundStyle(Theme.accent)
            if let sampleCheckResult { Text(sampleCheckResult).foregroundStyle(sampleCheckResult.hasPrefix("PASS") ? Theme.up : Theme.down) }
            Button("Run analytics sweep") { runSynchronousTask("analytics sweep") { sweepResult = AnalyticsSweep.runAnalyticsSweep().description } }
                .disabled(isRunningDebugTask || isLoadingSamples || isRunningChurnTest)
                .foregroundStyle(Theme.accent)
            if let sweepResult { Text(sweepResult).foregroundStyle(sweepResult.hasPrefix("PASS") ? Theme.up : Theme.down) }
            Button("Check stats math") { runStatsSelfCheck() }
                .disabled(isRunningDebugTask || isLoadingSamples || isRunningChurnTest)
                .foregroundStyle(Theme.accent)
            Button("Check recap cards") { runRecapCardCheck() }
                .disabled(isRunningDebugTask || isLoadingSamples || isRunningChurnTest)
                .foregroundStyle(Theme.accent)
            if let recapCardCheckResult {
                Text(recapCardCheckResult).foregroundStyle(recapCardCheckResult.hasPrefix("PASS") ? Theme.up : Theme.down)
                    .textSelection(.enabled)
            }
            if let statsSelfCheckResult {
                Text(statsSelfCheckResult).foregroundStyle(statsSelfCheckResult.hasPrefix("PASS") ? Theme.up : Theme.down)
                    .textSelection(.enabled)
            }
            if let timings = lastLoadTimings ?? DebugWorkState.lastSampleLoadTimings {
                diagnostic("Last sample load", timings.description)
            }
            if let sampleLoadResult {
                Text(sampleLoadResult).foregroundStyle(sampleLoadResult.hasPrefix("PASS") ? Theme.up : Theme.down)
                    .textSelection(.enabled)
            }
            Button("Delete invalid sessions") { deleteInvalidSessions() }
                .disabled(isRunningDebugTask || isLoadingSamples || isRunningChurnTest || !sessions.contains { !$0.hours.isFinite || $0.hours <= 0 })
                .foregroundStyle(Theme.down)
            Button("Clamp over-24 sessions to 24") { clampLongSessions() }
                .disabled(isRunningDebugTask || isLoadingSamples || isRunningChurnTest || !sessions.contains { $0.hours.isFinite && $0.hours > 24 })
                .foregroundStyle(Theme.down)
            Button {
                let hasData = !sessions.isEmpty || !entries.isEmpty || !activities.isEmpty || !metrics.isEmpty
                if hasData, replacementConfirmationExpiresAt.map({ $0 > .now }) != true {
                    replacementConfirmationExpiresAt = .now.addingTimeInterval(3)
                    return
                }
                let replacing = hasData
                replacementConfirmationExpiresAt = nil
                loadSamples(replacing: replacing)
            } label: {
                if appState.debugTaskRunner.isRunning { Label("Loading...", systemImage: "hourglass") }
                else if replacementConfirmationExpiresAt.map({ $0 > .now }) == true {
                    Text("Tap again to REPLACE sample data")
                } else { Text("Load sample data") }
            }
            .disabled(isRunningChurnTest)
            Button {
                if clearConfirmationExpiresAt.map({ $0 > .now }) == true {
                    clearConfirmationExpiresAt = nil
                    clearAllData()
                } else {
                    clearConfirmationExpiresAt = .now.addingTimeInterval(3)
                }
            } label: {
                Text(clearConfirmationExpiresAt.map({ $0 > .now }) == true ? "Tap again to CLEAR all data" : "Clear all data")
            }
            .disabled(isRunningChurnTest)
            .foregroundStyle(Theme.down)
            eventList(title: "MODEL SAVES", events: diagnostics.saveEvents.map(\.summary))
            eventList(title: "TAB CHANGE STACKS", events: diagnostics.tabChanges.map {
                "\($0.date.formatted(date: .omitted, time: .standard)) \($0.from)->\($0.to)\n\($0.frames.joined(separator: "\n"))"
            })
    }

    private func probeValue(_ label: String, _ rect: CGRect?) -> some View {
        let matches = rect.map(screenProbe.matchesBounds) ?? false
        return HStack(alignment: .top) {
            Text(label).foregroundStyle(Theme.textSecondary)
            Spacer(minLength: Theme.Spacing.sm)
            Text("\(matches ? "PASS" : "FLAG"): \(rect.map(String.init(describing:)) ?? "unavailable")")
                .foregroundStyle(matches ? Theme.up : Theme.down)
                .multilineTextAlignment(.trailing).textSelection(.enabled)
        }
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

    private func runStatsSelfCheck() {
        runSynchronousTask("stats math") {
            statsSelfCheckResult = StatsAnalyticsSelfCheck.run()
        }
    }

    private func runRecapCardCheck() {
        guard DebugWorkState.beginDebugTask() else {
            appState.debugTaskRunner.report("Skipped: another debug task is running.")
            return
        }
        currentTaskName = "recap card checks"
        isRunningDebugTask = true
        defer {
            currentTaskName = nil
            isRunningDebugTask = false
            DebugWorkState.finishDebugTask()
        }
        recapCardCheckResult = RecapCardChecks.run()
    }

    private func runSynchronousTask(_ name: String, action: () -> Void) {
        guard DebugWorkState.beginDebugTask() else {
            appState.debugTaskRunner.report("Skipped: another debug task is running.")
            return
        }
        isRunningDebugTask = true
        currentTaskName = name
        defer {
            currentTaskName = nil
            isRunningDebugTask = false
            DebugWorkState.finishDebugTask()
        }
        if name == "sample check" { selfTestResult = nil }
        action()
    }

    private func deleteInvalidSessions() {
        repairData(mode: .invalidSessionsOnly)
    }

    private func clampLongSessions() {
        repairData(mode: .clampLongSessionsOnly)
    }

    private func repairData(mode: DebugDataOperations.RepairMode) {
        guard !isSeeding && !DebugWorkState.isSeeding else {
            appState.debugTaskRunner.report("Skipped: a data change is already in progress.")
            return
        }
        selfTestResult = nil
        currentTaskName = "repair"
        isRunningDebugTask = true
        isSeeding = true
        Task { @MainActor in
            await appState.debugTaskRunner.repairData(in: context, appState: appState, mode: mode)
            if appState.debugTaskRunner.status.hasPrefix("FAILED:") {
                errorMessage = appState.debugTaskRunner.status
            }
            isSeeding = false
            observedSeeding = DebugWorkState.isSeeding
            observedGeneration = DebugWorkState.generation
            currentTaskName = nil
            isRunningDebugTask = false
        }
    }

    private func loadSamples(replacing: Bool) {
        guard !isLoadingSamples, !DebugWorkState.isSeeding, !isSeeding else {
            appState.debugTaskRunner.report("Skipped: sample data is already loading.")
            return
        }
        selfTestResult = nil
        currentTaskName = "sample data"
        isRunningDebugTask = true
        isLoadingSamples = true
        isSeeding = true
        sampleLoadResult = nil
        DebugWorkState.setSampleLoadResult(nil)
        Task { @MainActor in
            await appState.debugTaskRunner.loadSamples(in: context, appState: appState, replacing: replacing)
            if let timings = DebugWorkState.lastSampleLoadTimings,
               !appState.debugTaskRunner.status.hasPrefix("FAILED:") {
                lastLoadTimings = timings
                sampleLoadResult = "PASS: \(timings.description)"
            } else {
                sampleLoadResult = appState.debugTaskRunner.status
                if appState.debugTaskRunner.status.hasPrefix("FAILED:") {
                    errorMessage = appState.debugTaskRunner.status
                }
            }
            isLoadingSamples = false
            isSeeding = false
            observedSeeding = DebugWorkState.isSeeding
            observedGeneration = DebugWorkState.generation
            diagnostics.observe(context)
            currentTaskName = nil
            isRunningDebugTask = false
        }
    }

    private func clearAllData() {
        guard !DebugWorkState.isSeeding, !isSeeding else {
            appState.debugTaskRunner.report("Skipped: a data change is already in progress.")
            return
        }
        selfTestResult = nil
        currentTaskName = "clear data"
        isRunningDebugTask = true
        Task { @MainActor in
            isSeeding = true
            await appState.debugTaskRunner.clearData(in: context, appState: appState)
            if appState.debugTaskRunner.status.hasPrefix("FAILED:") {
                errorMessage = appState.debugTaskRunner.status
            }
            isSeeding = false
            observedSeeding = DebugWorkState.isSeeding
            observedGeneration = DebugWorkState.generation
            diagnostics.observe(context)
            currentTaskName = nil
            isRunningDebugTask = false
        }
    }

    private func runChurnTest() {
        guard !isLoadingSamples, !DebugWorkState.isSeeding, !isSeeding, !isRunningChurnTest else {
            appState.debugTaskRunner.report("Skipped: a debug data task is already running.")
            return
        }
        guard DebugWorkState.beginDebugTask() else {
            appState.debugTaskRunner.report("Skipped: another debug task is running.")
            return
        }
        selfTestResult = nil
        currentTaskName = "churn test"
        isRunningDebugTask = true
        isRunningChurnTest = true
        isSeeding = true
        Task { @MainActor in
            defer {
                isRunningChurnTest = false
                isSeeding = false
                observedSeeding = false
                observedGeneration = DebugWorkState.generation
                diagnostics.observe(context)
                currentTaskName = nil
                isRunningDebugTask = false
                DebugWorkState.finishDebugTask()
            }
            let report = await DebugDataOperations.runChurnTest(in: context, appState: appState)
            sampleCheckResult = nil
            sweepResult = nil
            lastLoadTimings = DebugWorkState.lastSampleLoadTimings
            errorMessage = report.hasPrefix("FAIL") ? report : nil
        }
    }

    private func runSelfTest() {
        guard DebugWorkState.beginDebugTask() else {
            appState.debugTaskRunner.report("Skipped: another debug task is running.")
            return
        }
        currentTaskName = "recap self-test"
        isRunningDebugTask = true
        selfTestResult = nil
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
            let variants = RecapMode.allCases.flatMap { mode in
                RecapCardFormat.allCases.flatMap { format in
                    let backgrounds: [RecapCardBackground] = mode == .day ? [.dark, .neon] : [.dark, .neon, .photo]
                    return backgrounds.map { (format: format, background: $0, mode: mode) }
                }
            }
            var failedRenders = 0
            for variant in variants {
                let rendered: Bool
                switch variant.mode {
                case .session:
                    let data = SessionRecapCardData(session: sessionValue,
                        activityHistory: [sessionValue, priorValue], allSessions: [sessionValue],
                        daySessions: [sessionValue], previousDaySessions: [priorValue], scores: [],
                        todayHours: 4, weekHours: 8, streakDays: 2,
                        caption: sessionValue.note, format: variant.format, background: variant.background)
                    rendered = render(SessionCard(data: data), format: variant.format)
                case .day:
                    let data = MarketCloseCardData(date: .now, sessions: [sessionValue],
                        previousDaySessions: [priorValue], sevenDayHours: [1, 2, 3, 4, 5, 6, 7],
                        scores: [MarketScoreValue(id: UUID(), name: "Sleep Score", value: 92, change: 4)],
                        format: variant.format, background: variant.background)
                    rendered = render(MarketCloseCard(data: data), format: variant.format)
                case .week:
                    let data = RecapCardFactory.weekly(.now, sessions: [], scores: [], now: .now,
                        format: variant.format, background: variant.background)
                    rendered = render(WeeklyCard(data: data), format: variant.format)
                }
                if !rendered { failedRenders += 1 }
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                let weeklyRenderFailures = runWeeklySelfTestRenders()
                do {
                    let end = try snapshot()
                    let differences = [
                        start.totalHoursBits == end.totalHoursBits ? nil : "hours \(start.totalHours) -> \(end.totalHours)",
                        start.count == end.count ? nil : "sessions \(start.count) -> \(end.count)",
                        start.tab == end.tab ? nil : "tab \(start.tab) -> \(end.tab)",
                        startSaves == diagnostics.saveEventCount ? nil : "save events \(startSaves) -> \(diagnostics.saveEventCount)",
                        failedRenders == 0 ? nil : "\(failedRenders) image renders returned nil",
                        weeklyRenderFailures.isEmpty ? nil : weeklyRenderFailures.joined(separator: "; ")
                    ].compactMap { $0 }
                    selfTestResult = differences.isEmpty
                        ? "PASS: 20 session/day renders plus 6 weekly renders; hours, sessions, tab and saves unchanged"
                        : "FAIL: " + differences.joined(separator: "; ")
                    NSLog("[RecapSelfTest] %@", selfTestResult ?? "FAIL: missing result")
                } catch {
                    selfTestResult = "FAIL: could not re-read sessions: \(error.localizedDescription)"
                    NSLog("[RecapSelfTest] %@", selfTestResult ?? "FAIL: missing result")
                }
                currentTaskName = nil
                isRunningDebugTask = false
                DebugWorkState.finishDebugTask()
            }
        } catch {
            selfTestResult = "FAIL: could not read sessions: \(error.localizedDescription)"
            NSLog("[RecapSelfTest] %@", selfTestResult ?? "FAIL: missing result")
            currentTaskName = nil
            isRunningDebugTask = false
            DebugWorkState.finishDebugTask()
        }
    }

    @MainActor private func runWeeklySelfTestRenders() -> [String] {
        var failures: [String] = []
        for format in RecapCardFormat.allCases {
            for background in [RecapCardBackground.dark, .neon, .photo] {
                let data = RecapCardFactory.weekly(.now, sessions: [], scores: [], now: .now,
                                                   format: format, background: background)
                if !render(WeeklyCard(data: data), format: format) {
                    failures.append("weekly \(format.rawValue) \(background.rawValue) render was nil")
                }
            }
        }
        return failures
    }

    @MainActor private func render<Card: View>(_ card: Card, format: RecapCardFormat) -> Bool {
        diagnostics.recordRecapRender()
        let renderer = ImageRenderer(content: card
            .environment(\.dynamicTypeSize, .large)
            .environment(\.colorScheme, .dark)
            .environment(\.locale, Locale(identifier: "en_US_POSIX")))
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(format.size)
        return renderer.uiImage != nil
    }
}


private struct ScreenProbeSnapshot {
    let screenBounds: CGRect
    let windowBounds: CGRect?
    let safeAreaInsets: UIEdgeInsets?
    let rootFrame: CGRect?
    let tabContainerFrame: CGRect?

    var safeAreaDescription: String {
        guard let safeAreaInsets else { return "FLAG: unavailable" }
        return "L \(safeAreaInsets.left), T \(safeAreaInsets.top), R \(safeAreaInsets.right), B \(safeAreaInsets.bottom)"
    }

    func matchesBounds(_ rect: CGRect) -> Bool {
        abs(rect.minX - screenBounds.minX) < 1 && abs(rect.minY - screenBounds.minY) < 1
            && abs(rect.width - screenBounds.width) < 1 && abs(rect.height - screenBounds.height) < 1
    }

    @MainActor static func capture() -> ScreenProbeSnapshot {
        let screen = UIScreen.main.bounds
        let window = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows).first(where: \.isKeyWindow)
        return ScreenProbeSnapshot(screenBounds: screen, windowBounds: window?.bounds,
                                   safeAreaInsets: window?.safeAreaInsets,
                                   rootFrame: DebugDiagnostics.shared.rootViewFrame,
                                   tabContainerFrame: DebugDiagnostics.shared.tabContainerFrame)
    }
}

#Preview {
    DebugDataTools().padding(Theme.Spacing.lg).background(Theme.background)
        .modelContainer(for: [Activity.self, Session.self, Metric.self, MetricEntry.self], inMemory: true)
        .environment(AppState())
}
#endif
