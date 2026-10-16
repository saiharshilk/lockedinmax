import Observation
import Foundation

enum AppTab: Int, CaseIterable, Hashable {
    case home
    case stats
    case log
    case recap
}

@Observable
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
#if DEBUG
    private(set) var sampleDataRefreshVersion = 0

    func sampleDataDidFinishLoading() {
        sampleDataRefreshVersion += 1
    }
#endif
}
