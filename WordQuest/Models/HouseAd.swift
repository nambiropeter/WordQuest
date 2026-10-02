import SwiftUI

/// First-party "suggested for you" content shown on Home — the app promoting
/// its own unexplored themes or local multiplayer, chosen from what a player
/// has (and hasn't) already played, entirely on-device. No third-party ad
/// network is involved.
struct HouseAd: Identifiable {
    enum Action {
        case openMultiplayer
        case openTheme(GameTheme)
    }

    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let gradient: LinearGradient
    let tintColor: Color
    let action: Action
}

@MainActor
enum HouseAdProvider {
    static func recommendation(progress: ProgressStore) -> HouseAd {
        guard progress.levelsCompleted > 0 else { return multiplayerAd }

        let themes = ContentStore.shared.themes
        guard let leastPlayed = themes.min(by: { engagement(progress, $0) < engagement(progress, $1) }) else {
            return multiplayerAd
        }

        return HouseAd(
            title: "Try \(leastPlayed.name)",
            subtitle: "You haven't explored this one yet — a fresh set of levels is waiting.",
            icon: leastPlayed.icon,
            gradient: leastPlayed.gradient,
            tintColor: leastPlayed.primaryColor,
            action: .openTheme(leastPlayed)
        )
    }

    private static func engagement(_ progress: ProgressStore, _ theme: GameTheme) -> Int {
        progress.themeLevelsCompleted(mode: .wordSearch, theme: theme)
            + progress.themeLevelsCompleted(mode: .trivia, theme: theme)
    }

    static var multiplayerAd: HouseAd {
        HouseAd(
            title: "Play together tonight",
            subtitle: "Invite up to 7 friends nearby for a live trivia round — no internet needed.",
            icon: "antenna.radiowaves.left.and.right",
            gradient: LinearGradient(colors: [Color(hex: "#118AB2"), Color(hex: "#073B4C")], startPoint: .top, endPoint: .bottom),
            tintColor: Color(hex: "#118AB2"),
            action: .openMultiplayer
        )
    }
}
