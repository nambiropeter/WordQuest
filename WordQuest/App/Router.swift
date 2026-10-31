import SwiftUI

@MainActor
final class Router: ObservableObject {
    @Published var path = NavigationPath()

    func push(_ route: AppRoute) {
        path.append(route)
    }

    /// Bumped by `replaceTop` and applied as the game screens' `.id`.
    /// NavigationStack identifies destinations by stack position, so swapping
    /// the top route in place would otherwise keep the old screen's
    /// @StateObject (e.g. the finished level, result overlay and all).
    @Published private(set) var session = UUID()

    /// Pops the current screen and pushes a new one with fresh view state.
    func replaceTop(with route: AppRoute) {
        if !path.isEmpty { path.removeLast() }
        path.append(route)
        session = UUID()
    }

    func popToRoot() {
        path.removeLast(path.count)
    }
}
