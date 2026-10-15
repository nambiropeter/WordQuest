import SwiftUI

struct RootView: View {
    @StateObject private var router = Router()

    var body: some View {
        NavigationStack(path: $router.path) {
            HomeView()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .themeSelect(let mode):
                        ThemeSelectView(mode: mode)
                    case .levelMap(let mode, let theme):
                        LevelMapView(mode: mode, theme: theme)
                    case .wordSearchGame(let theme, let level):
                        WordSearchView(theme: theme, level: level)
                            .id(router.session)
                    case .triviaGame(let theme, let level):
                        TriviaView(theme: theme, level: level)
                            .id(router.session)
                    case .settings:
                        SettingsView()
                    case .multiplayer(let theme):
                        MultiplayerLobbyView(initialTheme: theme)
                    }
                }
        }
        .environmentObject(router)
        .tint(.purple)
        .task {
            #if DEBUG
            // App Store screenshots: `-screenshotRoute <route>` opens that screen
            // directly and keeps Game Center / ad consent sheets out of the shot.
            if UserDefaults.standard.string(forKey: "screenshotRoute") != nil {
                if let route = Self.screenshotRoute { router.push(route) }
                return
            }
            #endif
            GameCenterManager.shared.authenticate()
            AdsManager.shared.start()
        }
    }

    #if DEBUG
    /// "themes:wordSearch", "map:trivia:science", "word:animals:12", "trivia:history:4",
    /// "multiplayer", or "home" (anything unrecognised stays on the home screen).
    private static var screenshotRoute: AppRoute? {
        guard let arg = UserDefaults.standard.string(forKey: "screenshotRoute") else { return nil }
        let parts = arg.split(separator: ":").map(String.init)
        let store = ContentStore.shared
        switch parts.first {
        case "themes":
            return .themeSelect(GameMode(rawValue: parts[1]) ?? .wordSearch)
        case "map":
            return .levelMap(GameMode(rawValue: parts[1]) ?? .wordSearch, store.theme(id: parts[2]))
        case "word":
            return .wordSearchGame(store.theme(id: parts[1]), Int(parts[2]) ?? 1)
        case "trivia":
            return .triviaGame(store.theme(id: parts[1]), Int(parts[2]) ?? 1)
        case "multiplayer":
            return .multiplayer(nil)
        default:
            return nil
        }
    }
    #endif
}
