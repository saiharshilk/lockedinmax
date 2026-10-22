import Observation
import Foundation

enum AppTab: Int, CaseIterable, Hashable {
    case home
    case stats
    case log
    case recap
}

@Observable @MainActor
final class AppState {
    @ObservationIgnored private var selectedTabStorage: AppTab = .home

    var selectedTab: AppTab {
        get { access(keyPath: \.selectedTab); return selectedTabStorage }
        set {
            withMutation(keyPath: \.selectedTab) {
                let oldValue = selectedTabStorage
                selectedTabStorage = newValue
#if DEBUG
                DebugDiagnostics.shared.recordTabChange(from: oldValue, to: newValue)
#endif
            }
        }
    }

    var sessionActivityID: UUID?
    var sessionRecapID: UUID?
    var logScoreRequested = false
    private(set) var navigationResetVersion = 0

    func prepareForBulkDataChange(switchToHome: Bool = false) {
        sessionActivityID = nil
        sessionRecapID = nil
        guard switchToHome else { return }
        selectedTab = .home
        navigationResetVersion += 1
    }

#if DEBUG
    private(set) var debugTaskRunner = DebugTaskRunner()
    private(set) var churnTestResult: String?

    func setChurnTestResult(_ result: String) {
        churnTestResult = result
    }

    func clearChurnTestResult() {
        churnTestResult = nil
    }

    private(set) var sampleDataRefreshVersion = 0

    func sampleDataDidFinishLoading() {
        sampleDataRefreshVersion += 1
    }
#endif
}
