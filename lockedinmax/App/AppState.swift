import Observation

enum AppTab: Int, CaseIterable, Hashable {
    case home
    case stats
    case log
    case recap
}

@Observable
final class AppState {
    var selectedTab: AppTab = .home
}
