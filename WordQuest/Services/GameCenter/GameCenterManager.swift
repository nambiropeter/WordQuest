import GameKit
import UIKit

/// Thin wrapper around GameKit. All Game Center calls in the app funnel
/// through here so the rest of the codebase never touches GameKit types
/// directly, and every call is a safe no-op when the player isn't signed in
/// (or when running somewhere Game Center can't authenticate, like a fresh
/// Simulator with no Apple ID). Leaderboard and achievement IDs below must
/// be created with matching identifiers in App Store Connect before real
/// data will appear — the code is ready for that the moment it's done.
@MainActor
final class GameCenterManager: NSObject, ObservableObject {
    static let shared = GameCenterManager()

    @Published private(set) var isAuthenticated = false

    enum LeaderboardID {
        static let wordSearchTotalScore = "wq_wordsearch_total_score"
        static let triviaTotalScore = "wq_trivia_total_score"
        static let totalStars = "wq_total_stars"
    }

    enum AchievementID {
        static let firstWin = "wq_first_win"
        static let hundredLevels = "wq_hundred_levels"
        static let perfectTrivia = "wq_perfect_trivia_round"
        static let multiplayerChampion = "wq_multiplayer_champion"
    }

    private override init() {
        super.init()
    }

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor in
                guard let self else { return }
                if let viewController {
                    self.present(viewController)
                } else if GKLocalPlayer.local.isAuthenticated {
                    self.isAuthenticated = true
                    GKAccessPoint.shared.isActive = true
                    GKAccessPoint.shared.location = .topLeading
                    GKAccessPoint.shared.showHighlights = true
                } else {
                    self.isAuthenticated = false
                    if let error {
                        print("Game Center authentication unavailable: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private func present(_ viewController: UIViewController) {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })?
            .windows.first(where: \.isKeyWindow)?.rootViewController else { return }
        root.present(viewController, animated: true)
    }

    func submitScore(_ score: Int, leaderboardID: String) {
        guard isAuthenticated, score > 0 else { return }
        Task {
            do {
                try await GKLeaderboard.submitScore(
                    score,
                    context: 0,
                    player: GKLocalPlayer.local,
                    leaderboardIDs: [leaderboardID]
                )
            } catch {
                print("Game Center score submission failed: \(error.localizedDescription)")
            }
        }
    }

    func reportAchievement(_ id: String, percentComplete: Double = 100) {
        guard isAuthenticated else { return }
        let achievement = GKAchievement(identifier: id)
        achievement.percentComplete = percentComplete
        achievement.showsCompletionBanner = true
        Task {
            do {
                try await GKAchievement.report([achievement])
            } catch {
                print("Game Center achievement report failed: \(error.localizedDescription)")
            }
        }
    }
}
