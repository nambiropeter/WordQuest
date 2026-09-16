import Foundation

/// Produces 1000 deterministic, distinct levels per theme, per game mode, by
/// combining curated per-theme content pools with a seeded generator keyed on
/// theme + level index. The same (theme, level) always yields the same puzzle,
/// but each level draws a different word/question subset, grid size, and
/// difficulty band as you progress. Because generation is keyed by theme
/// rather than derived from a single global sequence, players can jump into
/// any theme's own 1-1000 progression independently.
enum LevelCatalog {
    static let totalLevels = GameMode.levelCount

    private static func band(forLevel level: Int) -> Int {
        min((level - 1) / 100, 9) // 0...9
    }

    private static func themeSeedBase(_ theme: GameTheme) -> Int {
        abs(theme.id.hashValue % 1_000_000)
    }

    // MARK: - Word Search

    static func wordSearchLevel(theme: GameTheme, level: Int) -> WordSearchPuzzle {
        let b = band(forLevel: level)
        let gridSize = min(8 + b, 14)
        let wordCount = min(5 + b / 2, 10)
        let hintsAllowed = max(1, 3 - b / 4)
        let base = themeSeedBase(theme)

        let pool = ContentStore.shared.words(for: theme.id).filter { $0.count <= gridSize }
        var rng = SeededGenerator(seed: base * 7919 + level * 13 + 1)
        let selected = Array(pool.shuffled(using: &rng).prefix(wordCount))

        let (letters, placed) = WordSearchGenerator.generate(
            words: selected,
            gridSize: gridSize,
            seed: base * 104729 + level * 3 + 2
        )

        return WordSearchPuzzle(
            levelIndex: level,
            theme: theme,
            gridSize: gridSize,
            letters: letters,
            placedWords: placed,
            hintsAllowed: hintsAllowed
        )
    }

    // MARK: - Trivia

    static func triviaLevel(theme: GameTheme, level: Int) -> TriviaLevel {
        let b = band(forLevel: level)
        let questionCount = min(5 + b / 3, 8)
        let timePerQuestion = max(10, 20 - b)
        let base = themeSeedBase(theme)

        let pool = ContentStore.shared.questions(for: theme.id)
        var rng = SeededGenerator(seed: base * 15485863 + level * 27 + 3)

        let targetDifficulty: TriviaDifficulty = b < 3 ? .easy : (b < 7 ? .medium : .hard)
        let weighted = pool.sorted { lhs, rhs in
            let lhsMatch = lhs.difficulty == targetDifficulty
            let rhsMatch = rhs.difficulty == targetDifficulty
            if lhsMatch != rhsMatch { return lhsMatch && !rhsMatch }
            return false
        }
        let shuffled = weighted.shuffled(using: &rng)
        let chosen = Array(shuffled.prefix(questionCount))

        let questions = chosen.map { data in
            TriviaQuestion(
                text: data.q,
                options: data.options,
                correctIndex: data.answer,
                difficulty: data.difficulty
            )
        }

        return TriviaLevel(levelIndex: level, theme: theme, questions: questions, timePerQuestion: timePerQuestion)
    }

    /// Pulls a genuinely random (non-seeded) set of questions across one theme
    /// or, when `theme` is nil, mixed across all themes. Used for local multiplayer.
    static func randomQuestions(theme: GameTheme?, count: Int) -> [TriviaQuestion] {
        let pool: [TriviaQuestionData]
        if let theme {
            pool = ContentStore.shared.questions(for: theme.id)
        } else {
            pool = ContentStore.shared.themes.flatMap { ContentStore.shared.questions(for: $0.id) }
        }
        return Array(pool.shuffled().prefix(count)).map { data in
            TriviaQuestion(text: data.q, options: data.options, correctIndex: data.answer, difficulty: data.difficulty)
        }
    }
}
