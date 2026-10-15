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
    var selectedTab: AppTab = .home
    var sessionActivityID: UUID?
    var sessionRecapID: UUID?
    var logScoreRequested = false
}
