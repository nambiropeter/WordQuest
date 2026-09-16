import SwiftUI
import Combine

enum AnswerState {
    case unanswered, correct, wrong
}

@MainActor
final class TriviaViewModel: ObservableObject {
    @Published private(set) var triviaLevel: TriviaLevel
    @Published private(set) var currentIndex = 0
    @Published private(set) var score = 0
    @Published private(set) var streak = 0
    @Published private(set) var bestStreak = 0
    @Published private(set) var selectedIndex: Int?
    @Published private(set) var answerState: AnswerState = .unanswered
    @Published private(set) var eliminatedOptions: Set<Int> = []
    @Published private(set) var fiftyFiftyUsed = false
    @Published private(set) var timeRemaining: Int
    @Published private(set) var isComplete = false
    @Published private(set) var correctCount = 0

    private var timer: Timer?
    private var questionDeadline: Date = .now
    let level: Int
    let theme: GameTheme

    init(theme: GameTheme, level: Int) {
        self.theme = theme
        self.level = level
        let l = LevelCatalog.triviaLevel(theme: theme, level: level)
        self.triviaLevel = l
        self.timeRemaining = l.timePerQuestion
    }

    var currentQuestion: TriviaQuestion { triviaLevel.questions[currentIndex] }
    var totalQuestions: Int { triviaLevel.questions.count }
    var isLastQuestion: Bool { currentIndex == totalQuestions - 1 }

    func startQuestionTimer() {
        stopTimer()
        timeRemaining = triviaLevel.timePerQuestion
        questionDeadline = Date().addingTimeInterval(TimeInterval(triviaLevel.timePerQuestion))
        syncLiveActivity(isAnswered: false, lastAnswerCorrect: nil)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.timeRemaining > 0 {
                    self.timeRemaining -= 1
                    if self.timeRemaining <= 3 { SoundManager.tick() }
                } else {
                    self.timeExpired()
                }
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func timeExpired() {
        guard answerState == .unanswered else { return }
        answerState = .wrong
        streak = 0
        stopTimer()
        Haptics.error()
        SoundManager.wrongAnswer()
        syncLiveActivity(isAnswered: true, lastAnswerCorrect: false)
    }

    private func syncLiveActivity(isAnswered: Bool, lastAnswerCorrect: Bool?) {
        if TriviaActivityManager.shared.hasActiveActivity {
            TriviaActivityManager.shared.update(
                questionIndex: currentIndex,
                totalQuestions: totalQuestions,
                score: score,
                streak: streak,
                questionDeadline: questionDeadline,
                timePerQuestion: triviaLevel.timePerQuestion,
                isAnswered: isAnswered,
                lastAnswerCorrect: lastAnswerCorrect
            )
        } else {
            TriviaActivityManager.shared.start(
                theme: theme,
                level: level,
                totalQuestions: totalQuestions,
                timePerQuestion: triviaLevel.timePerQuestion,
                questionDeadline: questionDeadline
            )
        }
    }

    /// Called if the player backs out of a round before finishing it.
    func cancelLiveActivity() {
        TriviaActivityManager.shared.cancel()
    }

    func selectAnswer(_ index: Int) {
        guard answerState == .unanswered else { return }
        selectedIndex = index
        stopTimer()

        if index == currentQuestion.correctIndex {
            answerState = .correct
            streak += 1
            bestStreak = max(bestStreak, streak)
            correctCount += 1
            let speedBonus = timeRemaining * 5
            let streakBonus = min(streak * 10, 100)
            score += currentQuestion.difficulty.points + speedBonus + streakBonus
            Haptics.success()
            HapticsPlayer.shared.playCorrectPulse()
            SoundManager.correctAnswer()
        } else {
            answerState = .wrong
            streak = 0
            Haptics.error()
            SoundManager.wrongAnswer()
        }
        syncLiveActivity(isAnswered: true, lastAnswerCorrect: answerState == .correct)
    }

    func useFiftyFifty() {
        guard !fiftyFiftyUsed, answerState == .unanswered else { return }
        fiftyFiftyUsed = true
        let wrongIndices = currentQuestion.options.indices.filter { $0 != currentQuestion.correctIndex }
        eliminatedOptions = Set(wrongIndices.shuffled().prefix(2))
        Haptics.light()
    }

    func advance() {
        if isLastQuestion {
            finish()
            return
        }
        currentIndex += 1
        selectedIndex = nil
        answerState = .unanswered
        eliminatedOptions = []
        startQuestionTimer()
    }

    private func finish() {
        isComplete = true
        stopTimer()
        HapticsPlayer.shared.playLevelComplete()
        TriviaActivityManager.shared.end(finalScore: score)
        let stars = computeStars()
        ProgressStore.shared.recordCompletion(
            level: level,
            mode: .trivia,
            theme: theme,
            stars: stars,
            score: score,
            timeSeconds: 0
        )
        if correctCount == totalQuestions, totalQuestions > 0 {
            GameCenterManager.shared.reportAchievement(GameCenterManager.AchievementID.perfectTrivia)
        }
    }

    func computeStars() -> Int {
        let ratio = totalQuestions == 0 ? 0 : Double(correctCount) / Double(totalQuestions)
        if ratio >= 0.9 { return 3 }
        if ratio >= 0.6 { return 2 }
        if ratio > 0 { return 1 }
        return 0
    }
}
