#if DEBUG
import Foundation
import Observation
import SwiftData

struct SampleLoadTimings: CustomStringConvertible {
    let generationMilliseconds: Double
    let insertionMilliseconds: Double
    let saveMilliseconds: Double
    let sessions: Int
    let activities: Int
    let metrics: Int
    let entries: Int
    let totalSessions: Int
    let totalActivities: Int
    let totalMetrics: Int
    let totalEntries: Int
    let extraSessions: Int
    let extraActivities: Int
    let extraMetrics: Int
    let extraEntries: Int
    var totalMilliseconds: Double { generationMilliseconds + insertionMilliseconds + saveMilliseconds }

    var description: String {
        String(format: "Loaded %d sessions, %d positions, %d metrics, %d entries in %.1f s",
               sessions, activities, metrics, entries, totalMilliseconds / 1_000)
    }

    var resultLine: String {
        "SAMPLE_LOAD result=OK sessions=\(sessions) activities=\(activities) metrics=\(metrics) entries=\(entries)"
    }
}

/// Deliberately not Observable: reading the seed flag must not subscribe views to writes during batch inserts.
enum DebugWorkState {
    private static let lock = NSLock()
    private static var seeding = false
    private static var timings: SampleLoadTimings?
    private static var refreshVersion = 0
    private static var runningDebugTask = false
    private static var sampleLoadResult: String?

    static var isRunningDebugTask: Bool {
        lock.lock()
        defer { lock.unlock() }
        return runningDebugTask
    }

    static func beginDebugTask() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !runningDebugTask else { return false }
        runningDebugTask = true
        return true
    }

    static func finishDebugTask() {
        lock.lock()
        runningDebugTask = false
        lock.unlock()
    }

    static func resetDebugFlags() {
        lock.lock()
        runningDebugTask = false
        seeding = false
        lock.unlock()
    }

    static var isSeeding: Bool {
        lock.lock()
        defer { lock.unlock() }
        return seeding
    }

    static var generation: Int {
        lock.lock()
        defer { lock.unlock() }
        return refreshVersion
    }

    static var lastSampleLoadTimings: SampleLoadTimings? {
        lock.lock()
        defer { lock.unlock() }
        return timings
    }

    static var lastSampleLoadResult: String? {
        lock.lock()
        defer { lock.unlock() }
        return sampleLoadResult
    }

    static func setSampleLoadResult(_ result: String?) {
        lock.lock()
        sampleLoadResult = result
        lock.unlock()
    }

    static func clearSampleLoadResult() {
        lock.lock()
        timings = nil
        sampleLoadResult = nil
        lock.unlock()
    }

    static func beginSeeding() {
        lock.lock()
        seeding = true
        lock.unlock()
    }

    static func seedCalculus(in context: ModelContext) throws {
        let activities = try context.fetch(FetchDescriptor<Activity>())
        let activity = activities.first(where: { $0.name.localizedCaseInsensitiveCompare("Calculus") == .orderedSame })
            ?? Activity(name: "Calculus", colorHex: Theme.activityColorPresets[0], iconName: "function")
        if !activities.contains(where: { $0.id == activity.id }) { context.insert(activity) }
        context.insert(Session(date: .now, hours: 2.0, activity: activity))
        try context.save()
    }

    static func finishSeeding(timings newTimings: SampleLoadTimings?) {
        lock.lock()
        timings = newTimings
        refreshVersion += 1
        seeding = false
        lock.unlock()
    }
}

extension SampleLoadTimings {
    func withTotalCounts(_ counts: SampleData.Counts) -> SampleLoadTimings {
        SampleLoadTimings(generationMilliseconds: generationMilliseconds,
                         insertionMilliseconds: insertionMilliseconds, saveMilliseconds: saveMilliseconds,
                         sessions: sessions, activities: activities, metrics: metrics, entries: entries,
                         totalSessions: counts.sessions, totalActivities: counts.activities,
                         totalMetrics: counts.metrics, totalEntries: counts.entries,
                         extraSessions: counts.sessions - sessions, extraActivities: counts.activities - activities,
                         extraMetrics: counts.metrics - metrics, extraEntries: counts.entries - entries)
    }
}

@MainActor
enum DebugDataOperations {
    enum RepairMode {
        case invalidSessionsOnly
        case clampLongSessionsOnly
        case allBadData
    }

    static func loadSamples(in context: ModelContext, appState: AppState,
                            replacing: Bool, switchToHome: Bool = false) async throws -> SampleLoadTimings {
        await beginBulkChange(appState: appState, switchToHome: switchToHome)
        let originalAutosave = context.autosaveEnabled
        context.autosaveEnabled = false
        var finalTimings: SampleLoadTimings?
        defer {
            context.autosaveEnabled = originalAutosave
            finishBulkChange(appState: appState, timings: finalTimings)
        }
        do {
            let timings = try SampleData.load(into: context, replacingExisting: replacing)
            let counts = try SampleData.counts(in: context)
            let result = timings.withTotalCounts(counts)
            finalTimings = result
            DebugWorkState.setSampleLoadResult(result.resultLine)
            return result
        } catch {
            context.rollback()
            let failure = "SAMPLE_LOAD result=FAILED reason=\(error.localizedDescription)"
            DebugWorkState.setSampleLoadResult(failure)
            throw error
        }
    }

    static func clearData(in context: ModelContext, appState: AppState, switchToHome: Bool = false) async throws {
        await beginBulkChange(appState: appState, switchToHome: switchToHome)
        defer { finishBulkChange(appState: appState, timings: nil) }
        do {
            try SampleData.clear(context)
        } catch {
            context.rollback()
            throw error
        }
    }

    static func repairData(in context: ModelContext, appState: AppState,
                           mode: RepairMode = .allBadData, switchToHome: Bool = false) async throws {
        await beginBulkChange(appState: appState, switchToHome: switchToHome)
        defer { finishBulkChange(appState: appState, timings: nil) }
        do {
            let sessions = try context.fetch(FetchDescriptor<Session>())
            for session in sessions {
                let invalid = !session.hours.isFinite || session.hours <= 0
                switch mode {
                case .invalidSessionsOnly where invalid:
                    context.delete(session)
                case .clampLongSessionsOnly where session.hours.isFinite && session.hours > 24:
                    session.hours = 24
                case .allBadData where invalid:
                    context.delete(session)
                case .allBadData where session.hours.isFinite && session.hours > 24:
                    session.hours = 24
                default:
                    break
                }
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    static func runChurnTest(in context: ModelContext, appState: AppState) async -> String {
        appState.clearChurnTestResult()
        appState.prepareForBulkDataChange(switchToHome: true)
        DebugWorkState.beginSeeding()
        DebugWorkState.finishSeeding(timings: nil)
        appState.sampleDataDidFinishLoading()
        var cycleResults: [String] = []
        do {
            if try context.fetchCount(FetchDescriptor<Session>()) == 0 {
                _ = try await loadSamples(in: context, appState: appState, replacing: false, switchToHome: true)
            }
            for cycle in 1...10 {
                if let session = try context.fetch(FetchDescriptor<Session>()).first {
                    appState.sessionRecapID = session.id
                }
                appState.selectedTab = .recap
                try await Task.sleep(for: .milliseconds(300))
                let cycleStart = ProcessInfo.processInfo.systemUptime
                let replacement = try await loadSamples(in: context, appState: appState, replacing: true, switchToHome: true)
                try await Task.sleep(for: .milliseconds(300))
                try await clearData(in: context, appState: appState, switchToHome: true)
                try await Task.sleep(for: .milliseconds(300))
                let finalLoad = try await loadSamples(in: context, appState: appState, replacing: false, switchToHome: true)
                try await repairData(in: context, appState: appState, mode: .allBadData, switchToHome: true)
                let elapsed = (ProcessInfo.processInfo.systemUptime - cycleStart) * 1_000
                cycleResults.append(String(format: "cycle %02d: %.1f ms (replace %.1f, final load %.1f)",
                                           cycle, elapsed, replacement.totalMilliseconds,
                                           finalLoad.totalMilliseconds))
                NSLog("[ChurnTest] %@", cycleResults.last!)
            }
            let counts = try SampleData.counts(in: context)
            let invalid = try context.fetch(FetchDescriptor<Session>()).filter {
                !$0.hours.isFinite || $0.hours <= 0 || $0.hours > 24
            }.count
            let pass = counts.sessions == 171 && counts.activities == 7
                && counts.metrics == 3 && counts.entries == 75 && invalid == 0
            let report = "\(pass ? "PASS" : "FAIL"): 10 cycles; final \(counts); invalid=\(invalid)\n"
                + cycleResults.joined(separator: "\n")
            appState.setChurnTestResult(report)
            NSLog("[ChurnTest] %@", report)
            return report
        } catch {
            let report = "FAIL: churn test stopped after \(cycleResults.count) completed cycles: \(error.localizedDescription)\n"
                + cycleResults.joined(separator: "\n")
            appState.setChurnTestResult(report)
            NSLog("[ChurnTest] %@", report)
            return report
        }
    }

    @MainActor private static func beginBulkChange(appState: AppState, switchToHome: Bool = false) async {
        appState.prepareForBulkDataChange(switchToHome: switchToHome)
        DebugWorkState.beginSeeding()
        await Task.yield()
    }

    @MainActor private static func finishBulkChange(appState: AppState, timings: SampleLoadTimings?) {
        DebugWorkState.finishSeeding(timings: timings)
        appState.sampleDataDidFinishLoading()
    }
}

@MainActor @Observable
final class DebugTaskRunner {
    private(set) var status = "Ready — no debug task has run."

    func report(_ message: String) { status = message }
    private(set) var isRunning = false
    private(set) var task: Task<Void, Never>?
    private var operationID: UUID?

    func loadSamples(in context: ModelContext, appState: AppState, replacing: Bool) async {
        DebugWorkState.clearSampleLoadResult()
        await perform(starting: "Loading...") { [weak self] in
            let timings = try await DebugDataOperations.loadSamples(in: context, appState: appState,
                                                                     replacing: replacing)
            self?.status = "\(timings.description)"
            print(timings.resultLine)
            NSLog("[SampleLoad] %@", timings.resultLine)
            fflush(stdout)
        }
    }

    func clearData(in context: ModelContext, appState: AppState) async {
        await perform(starting: "Clearing data...") { [weak self] in
            try await DebugDataOperations.clearData(in: context, appState: appState)
            self?.status = "Cleared all positions, sessions, metrics, and entries."
        }
    }

    func repairData(in context: ModelContext, appState: AppState,
                    mode: DebugDataOperations.RepairMode) async {
        await perform(starting: "Repairing data...") { [weak self] in
            try await DebugDataOperations.repairData(in: context, appState: appState, mode: mode)
            self?.status = "Data repair completed."
        }
    }

    func resetFlags() {
        operationID = nil
        task?.cancel()
        task = nil
        isRunning = false
        DebugWorkState.resetDebugFlags()
        DebugWorkState.clearSampleLoadResult()
        status = "Debug flags reset."
    }


    private func perform(starting message: String,
                         operation: @escaping @MainActor () async throws -> Void) async {
        guard !isRunning, DebugWorkState.beginDebugTask() else {
            status = "Skipped: another debug task is running."
            return
        }
        isRunning = true
        status = message
        let id = UUID()
        operationID = id
        task = Task { @MainActor in
            let oldTimings = DebugWorkState.lastSampleLoadTimings
            defer {
                if DebugWorkState.isSeeding {
                    DebugWorkState.finishSeeding(timings: DebugWorkState.lastSampleLoadTimings ?? oldTimings)
                }
                if self.operationID == id {
                    self.task = nil
                    self.isRunning = false
                    self.operationID = nil
                    DebugWorkState.finishDebugTask()
                }
            }
            do {
                DebugWorkState.beginSeeding()
                try await operation()
            } catch {
                self.status = "FAILED: \(error.localizedDescription)"
                let reason = String(error.localizedDescription.map { $0.isWhitespace ? Character("-") : $0 })
                let line = "SAMPLE_LOAD result=FAILED reason=\(reason)"
                DebugWorkState.setSampleLoadResult(line)
                print(line)
                NSLog("[SampleLoad] %@", line)
                fflush(stdout)
            }
        }
        await task?.value
    }
}

extension DebugDataOperations {
    static func launchChurnTestIfRequested(in context: ModelContext, appState: AppState) async {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--churn-test"), !arguments.contains("--churn-test-completed") else { return }
        let report = await runChurnTest(in: context, appState: appState)
        NSLog("[ChurnTestArgument] %@", report)
        fflush(stdout)
        fflush(stderr)
    }

}
#endif
