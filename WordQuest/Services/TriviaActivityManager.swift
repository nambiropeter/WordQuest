import ActivityKit
import Foundation

/// Starts, updates, and ends the Dynamic Island / Lock Screen Live Activity
/// for a solo trivia round. Every entry point is a safe no-op when Live
/// Activities aren't available (disabled in Settings, or an older iOS) or
/// when there's no active activity to act on.
@MainActor
final class TriviaActivityManager {
    static let shared = TriviaActivityManager()

    private var activity: Activity<TriviaActivityAttributes>?

    var hasActiveActivity: Bool { activity != nil }

    private var isAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func start(theme: GameTheme, level: Int, totalQuestions: Int, timePerQuestion: Int, questionDeadline: Date) {
        guard isAvailable, activity == nil else { return }
        let attributes = TriviaActivityAttributes(
            themeName: theme.name,
            themeIcon: theme.icon,
            themeColorPrimaryHex: theme.colorPrimary,
            themeColorSecondaryHex: theme.colorSecondary,
            level: level
        )
        let state = TriviaActivityAttributes.ContentState(
            questionIndex: 0,
            totalQuestions: totalQuestions,
            score: 0,
            streak: 0,
            questionDeadline: questionDeadline,
            timePerQuestion: timePerQuestion,
            isAnswered: false,
            lastAnswerCorrect: nil
        )
        do {
            activity = try Activity.request(attributes: attributes, content: .init(state: state, staleDate: nil))
        } catch {
            print("Live Activity failed to start: \(error.localizedDescription)")
        }
    }

    /// Called once per question boundary and once per answer — never on a
    /// per-second tick, since the countdown itself is system-rendered.
    func update(
        questionIndex: Int,
        totalQuestions: Int,
        score: Int,
        streak: Int,
        questionDeadline: Date,
        timePerQuestion: Int,
        isAnswered: Bool,
        lastAnswerCorrect: Bool?
    ) {
        guard let activity else { return }
        let state = TriviaActivityAttributes.ContentState(
            questionIndex: questionIndex,
            totalQuestions: totalQuestions,
            score: score,
            streak: streak,
            questionDeadline: questionDeadline,
            timePerQuestion: timePerQuestion,
            isAnswered: isAnswered,
            lastAnswerCorrect: lastAnswerCorrect
        )
        Task { await activity.update(.init(state: state, staleDate: nil)) }
    }

    func end(finalScore: Int) {
        guard let activity else { return }
        var final = activity.content.state
        final.score = finalScore
        final.isAnswered = true
        Task { await activity.end(.init(state: final, staleDate: nil), dismissalPolicy: .after(.now + 4)) }
        self.activity = nil
    }

    func cancel() {
        guard let activity else { return }
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
        self.activity = nil
    }
}
