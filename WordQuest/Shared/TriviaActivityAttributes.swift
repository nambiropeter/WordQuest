import ActivityKit
import Foundation

/// Shared between the app and the WordQuestActivity widget extension (both
/// targets compile this same file). The per-question timer is driven by the
/// system, not the app: we hand it a fixed `questionDeadline` once per
/// question and the widget renders a live-ticking `Text(timerInterval:)` /
/// `ProgressView(timerInterval:)`, which iOS updates on its own every second
/// with no additional Live Activity updates (and no extra battery cost)
/// required from the app.
struct TriviaActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var questionIndex: Int
        var totalQuestions: Int
        var score: Int
        var streak: Int
        var questionDeadline: Date
        var timePerQuestion: Int
        var isAnswered: Bool
        var lastAnswerCorrect: Bool?
    }

    var themeName: String
    var themeIcon: String
    var themeColorPrimaryHex: String
    var themeColorSecondaryHex: String
    var level: Int
}
