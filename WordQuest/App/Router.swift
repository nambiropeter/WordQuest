import SwiftUI

@MainActor
final class Router: ObservableObject {
    @Published var path = NavigationPath()

    func push(_ route: AppRoute) {
        path.append(route)
    }

    /// Pops the current screen and pushes a new one, giving the destination
    /// a fresh view identity (and therefore fresh @StateObject state).
    func replaceTop(with route: AppRoute) {
        if !path.isEmpty { path.removeLast() }
        path.append(route)
    }

    func popToRoot() {
        path.removeLast(path.count)
    }
}
