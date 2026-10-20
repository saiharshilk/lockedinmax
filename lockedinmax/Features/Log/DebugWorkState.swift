#if DEBUG
import Foundation
import SwiftData

struct SampleLoadTimings: CustomStringConvertible {
    let generationMilliseconds: Double
    let insertionMilliseconds: Double
    let saveMilliseconds: Double
    var totalMilliseconds: Double { generationMilliseconds + insertionMilliseconds + saveMilliseconds }

    var description: String {
        String(format: "generation %.1f ms · insertion %.1f ms · save %.1f ms · total %.1f ms",
               generationMilliseconds, insertionMilliseconds, saveMilliseconds, totalMilliseconds)
    }
}

/// Deliberately not Observable: reading the seed flag must not subscribe views to writes during batch inserts.
enum DebugWorkState {
    private static let lock = NSLock()
    private static var seeding = false
    private static var timings: SampleLoadTimings?
    private static var refreshVersion = 0
    private static var runningDebugTask = false

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

    static func beginSeeding() {
        lock.lock()
        seeding = true
        lock.unlock()
    }

    static func finishSeeding(timings newTimings: SampleLoadTimings?) {
        lock.lock()
        timings = newTimings
        refreshVersion += 1
        seeding = false
        lock.unlock()
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
                            replacing: Bool) async throws -> SampleLoadTimings {
        await beginBulkChange(appState: appState)
        let originalAutosave = context.autosaveEnabled
        context.autosaveEnabled = false
        do {
            let timings = try SampleData.load(into: context, replacingExisting: replacing)
            context.autosaveEnabled = originalAutosave
            finishBulkChange(appState: appState, timings: timings)
            return timings
        } catch {
            context.rollback()
            context.autosaveEnabled = originalAutosave
            finishBulkChange(appState: appState, timings: nil)
            throw error
        }
    }

    static func clearData(in context: ModelContext, appState: AppState) async throws {
        await beginBulkChange(appState: appState)
        do {
            try SampleData.clear(context)
            finishBulkChange(appState: appState, timings: nil)
        } catch {
            context.rollback()
            finishBulkChange(appState: appState, timings: nil)
            throw error
        }
    }

    static func repairData(in context: ModelContext, appState: AppState,
                           mode: RepairMode = .allBadData) async throws {
        await beginBulkChange(appState: appState)
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
            finishBulkChange(appState: appState, timings: nil)
        } catch {
            context.rollback()
            finishBulkChange(appState: appState, timings: nil)
            throw error
        }
    }

    static func runChurnTest(in context: ModelContext, appState: AppState) async -> String {
        appState.clearChurnTestResult()
        appState.prepareForBulkDataChange()
        DebugWorkState.beginSeeding()
        DebugWorkState.finishSeeding(timings: nil)
        appState.sampleDataDidFinishLoading()
        var cycleResults: [String] = []
        do {
            if try context.fetchCount(FetchDescriptor<Session>()) == 0 {
                _ = try await loadSamples(in: context, appState: appState, replacing: false)
            }
            for cycle in 1...10 {
                if let session = try context.fetch(FetchDescriptor<Session>()).first {
                    appState.sessionRecapID = session.id
                }
                appState.selectedTab = .recap
                try await Task.sleep(for: .milliseconds(300))
                let cycleStart = ProcessInfo.processInfo.systemUptime
                let replacement = try await loadSamples(in: context, appState: appState, replacing: true)
                try await Task.sleep(for: .milliseconds(300))
                try await clearData(in: context, appState: appState)
                try await Task.sleep(for: .milliseconds(300))
                let finalLoad = try await loadSamples(in: context, appState: appState, replacing: false)
                try await repairData(in: context, appState: appState, mode: .allBadData)
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

    @MainActor private static func beginBulkChange(appState: AppState) async {
        appState.prepareForBulkDataChange()
        DebugWorkState.beginSeeding()
        await Task.yield()
    }

    @MainActor private static func finishBulkChange(appState: AppState, timings: SampleLoadTimings?) {
        DebugWorkState.finishSeeding(timings: timings)
        appState.sampleDataDidFinishLoading()
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
