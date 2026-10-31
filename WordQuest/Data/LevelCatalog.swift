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
        abs(stableHash(theme.id) % 1_000_000)
    }

    /// `String.hashValue` is randomized per process launch (Swift seeds its hasher
    /// for DoS resistance), so using it here would make "deterministic" levels
    /// actually change every time the app relaunches. FNV-1a over the raw UTF-8
    /// bytes gives the same value every time, on every device, for the same theme id.
    private static func stableHash(_ string: String) -> Int {
        var hash: UInt64 = 0xcbf29ce484222325 // FNV offset basis
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3 // FNV prime
        }
        return Int(truncatingIfNeeded: hash)
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
        guard !pool.isEmpty else {
            return TriviaLevel(levelIndex: level, theme: theme, questions: [], timePerQuestion: timePerQuestion)
        }

        let buckets = Buckets(pool: pool)
        let quota = Self.quota(band: b, count: questionCount, available: buckets)

        // Each difficulty is dealt from its own "shoe": the infinite
        // concatenation of independently shuffled copies of that bucket.
        // Consecutive levels take consecutive slices, so every question in a
        // bucket is used once before any is used twice, and — because each
        // copy is shuffled separately — consecutive levels don't repeat the
        // same *set*. The offset is how many of that difficulty every earlier
        // level in this theme has already consumed, so coverage is even
        // across the whole 1...1000 run rather than restarting each band.
        var drawn: [TriviaQuestionData] = []
        drawn += deal(from: buckets.easy, seed: base &+ 11, offset: consumed(before: level, difficulty: .easy, available: buckets), count: quota.easy)
        drawn += deal(from: buckets.medium, seed: base &+ 22, offset: consumed(before: level, difficulty: .medium, available: buckets), count: quota.medium)
        drawn += deal(from: buckets.hard, seed: base &+ 33, offset: consumed(before: level, difficulty: .hard, available: buckets), count: quota.hard)

        // Interleave, so the harder questions aren't always the last ones.
        var orderRng = SeededGenerator(seed: base &* 7_741 &+ level &* 131 &+ 5)
        drawn = drawn.shuffled(using: &orderRng)

        var optionsRng = SeededGenerator(seed: base &* 50_000_017 &+ level &* 97 &+ 11)
        let questions = drawn.map { buildQuestion($0, using: &optionsRng) }

        return TriviaLevel(levelIndex: level, theme: theme, questions: questions, timePerQuestion: timePerQuestion)
    }

    /// The pool split by difficulty, so each class can be drawn from independently.
    private struct Buckets {
        let easy: [TriviaQuestionData]
        let medium: [TriviaQuestionData]
        let hard: [TriviaQuestionData]

        init(pool: [TriviaQuestionData]) {
            easy = pool.filter { $0.difficulty == .easy }
            medium = pool.filter { $0.difficulty == .medium }
            hard = pool.filter { $0.difficulty == .hard }
        }

        func count(_ difficulty: TriviaDifficulty) -> Int {
            switch difficulty {
            case .easy: return easy.count
            case .medium: return medium.count
            case .hard: return hard.count
            }
        }
    }

    private struct Quota {
        var easy = 0
        var medium = 0
        var hard = 0

        subscript(difficulty: TriviaDifficulty) -> Int {
            get {
                switch difficulty {
                case .easy: return easy
                case .medium: return medium
                case .hard: return hard
                }
            }
            set {
                switch difficulty {
                case .easy: easy = newValue
                case .medium: medium = newValue
                case .hard: hard = newValue
                }
            }
        }

        var total: Int { easy + medium + hard }
    }

    /// Target difficulty mix per band, in tenths. Band 0 is all easy and band
    /// 9 is mostly hard; the ramp in between is what makes a level *feel*
    /// harder as you climb, rather than the single easy/medium/hard flip the
    /// bands used to do.
    private static let difficultyWeights: [(easy: Int, medium: Int, hard: Int)] = [
        (10, 0, 0),
        (9, 1, 0),
        (7, 3, 0),
        (5, 5, 0),
        (3, 6, 1),
        (2, 6, 2),
        (1, 6, 3),
        (0, 6, 4),
        (0, 4, 6),
        (0, 2, 8),
    ]

    /// Apportions `count` questions across the three difficulties by the
    /// band's weights (largest remainder), then clamps each to how many
    /// distinct questions that bucket actually holds, spilling any shortfall
    /// to the nearest difficulty that still has room. With the current content
    /// — as few as two `hard` questions in a theme — the clamp is what
    /// actually binds at the top bands, not the weights.
    private static func quota(band b: Int, count: Int, available: Buckets) -> Quota {
        let weights = difficultyWeights[min(max(b, 0), difficultyWeights.count - 1)]
        let order: [TriviaDifficulty] = [.easy, .medium, .hard]
        let weightFor: [Int] = [weights.easy, weights.medium, weights.hard]
        let totalWeight = weightFor.reduce(0, +)

        var quota = Quota()
        var remainders: [(difficulty: TriviaDifficulty, remainder: Int)] = []
        for (index, difficulty) in order.enumerated() {
            let exact = count * weightFor[index]
            quota[difficulty] = exact / totalWeight
            remainders.append((difficulty, exact % totalWeight))
        }
        for entry in remainders.sorted(by: { $0.remainder > $1.remainder }) where quota.total < count {
            quota[entry.difficulty] += 1
        }

        // Clamp to what exists, then refill from the nearest difficulty with room.
        // A bucket big enough to spare one holds a question back: drawing a
        // whole bucket every level pins that part of the set, which is what
        // made the top band of a theme with exactly six `hard` questions serve
        // the same six every time. Buckets of three or fewer are exempt —
        // there, taking all of them is the only way to hit the target at all.
        for difficulty in order {
            let inBucket = available.count(difficulty)
            let ceiling = inBucket >= 4 ? inBucket - 1 : inBucket
            quota[difficulty] = min(quota[difficulty], ceiling)
        }
        let spillOrder: [TriviaDifficulty] = b >= 7 ? [.hard, .medium, .easy] : (b >= 4 ? [.medium, .hard, .easy] : [.easy, .medium, .hard])
        var progressed = true
        while quota.total < count, progressed {
            progressed = false
            for difficulty in spillOrder where quota.total < count && quota[difficulty] < (available.count(difficulty) >= 4 ? available.count(difficulty) - 1 : available.count(difficulty)) {
                quota[difficulty] += 1
                progressed = true
            }
        }
        return quota
    }

    /// How many questions of `difficulty` every level before `level` in this
    /// theme has already drawn — the shoe position this level starts from.
    private static func consumed(before level: Int, difficulty: TriviaDifficulty, available: Buckets) -> Int {
        let currentBand = band(forLevel: level)
        var total = 0
        for b in 0..<currentBand {
            let perLevel = quota(band: b, count: min(5 + b / 3, 8), available: available)[difficulty]
            total += perLevel * 100
        }
        let perLevel = quota(band: currentBand, count: min(5 + currentBand / 3, 8), available: available)[difficulty]
        return total + ((level - 1) % 100) * perLevel
    }

    /// Reads `count` questions out of `bucket`'s shoe starting at `offset`,
    /// skipping any that a straddled copy boundary would repeat within the
    /// same level.
    private static func deal(from bucket: [TriviaQuestionData], seed: Int, offset: Int, count: Int) -> [TriviaQuestionData] {
        guard count > 0, !bucket.isEmpty else { return [] }
        var result: [TriviaQuestionData] = []
        var seen = Set<String>()
        var position = offset
        let limit = offset + bucket.count * 4 // always enough; bounds the loop
        while result.count < count, position < limit {
            let copy = shuffledCopy(bucket, seed: seed, index: position / bucket.count)
            let candidate = copy[position % bucket.count]
            if seen.insert(candidate.q).inserted {
                result.append(candidate)
            }
            position += 1
        }
        return result
    }

    private static func shuffledCopy(_ bucket: [TriviaQuestionData], seed: Int, index: Int) -> [TriviaQuestionData] {
        var rng = SeededGenerator(seed: seed &+ index &* 7_919)
        return bucket.shuffled(using: &rng)
    }

    /// The stored data always lists the correct answer alongside its
    /// distractors in a fixed order (in this content, index 0 for 234 of the
    /// 240 questions), so building `TriviaQuestion.options` straight from
    /// `TriviaQuestionData.options` made the correct choice predictable —
    /// almost always option A. Shuffling the options, and remapping the
    /// correct index to match, fixes that while keeping single player
    /// deterministic per (theme, level) via the seeded `rng`.
    private static func buildQuestion(_ data: TriviaQuestionData, using rng: inout SeededGenerator) -> TriviaQuestion {
        let order = Array(data.options.indices).shuffled(using: &rng)
        return TriviaQuestion(
            text: data.q,
            options: order.map { data.options[$0] },
            correctIndex: order.firstIndex(of: data.answer) ?? 0,
            difficulty: data.difficulty
        )
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
            let order = Array(data.options.indices).shuffled()
            return TriviaQuestion(
                text: data.q,
                options: order.map { data.options[$0] },
                correctIndex: order.firstIndex(of: data.answer) ?? 0,
                difficulty: data.difficulty
            )
        }
    }
}
