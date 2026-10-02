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
            GameCenterManager.shared.authenticate()
            AdsManager.shared.start()
        }
    }
}
