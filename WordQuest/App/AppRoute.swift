import Foundation

enum AppRoute: Hashable {
    case themeSelect(GameMode)
    case levelMap(GameMode, GameTheme)
    case wordSearchGame(GameTheme, Int)
    case triviaGame(GameTheme, Int)
    case settings
    case multiplayer(GameTheme?)
}
