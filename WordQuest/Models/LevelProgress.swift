import Foundation

enum GameMode: String, Codable, CaseIterable {
    case wordSearch
    case trivia

    var displayName: String {
        switch self {
        case .wordSearch: return "Word Search"
        case .trivia: return "Trivia"
        }
    }

    var icon: String {
        switch self {
        case .wordSearch: return "square.grid.3x3.fill"
        case .trivia: return "questionmark.circle.fill"
        }
    }

    static let levelCount = 1000
    static let tierSize = 100
    static let tierCount = levelCount / tierSize
}

struct LevelResult: Codable {
    let stars: Int
    let bestScore: Int
    let bestTimeSeconds: Int
}

@MainActor
final class ProgressStore: ObservableObject {
    static let shared = ProgressStore()

    @Published private(set) var wordSearchResults: [String: LevelResult] = [:]
    @Published private(set) var triviaResults: [String: LevelResult] = [:]
    @Published private(set) var totalCoins: Int = 0
    /// Whether this device is signed into an iCloud account at all — shown in
    /// Settings so the sync status is never a silent mystery to the player.
    @Published private(set) var iCloudAvailable: Bool = FileManager.default.ubiquityIdentityToken != nil

    private let defaults = UserDefaults.standard
    private let cloud = NSUbiquitousKeyValueStore.default
    private let wordSearchKey = "wq.wordsearch.results.v2"
    private let triviaKey = "wq.trivia.results.v2"
    private let coinsKey = "wq.coins"
    /// NSUbiquitousKeyValueStore caps total storage at ~1MB; stay well clear
    /// of that so a save is never silently dropped by iCloud without warning.
    /// UserDefaults (checked first, always written) has no such ceiling, so a
    /// player's local save is never at risk even if sync is skipped.
    private let iCloudValueSizeLimit = 900_000

    private init() {
        load()
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.load() }
        }
        cloud.synchronize()
    }

    /// Loads local + iCloud saves and merges them (keeping the best result
    /// per level from either side), then writes the merged result back to
    /// both stores. This runs at launch and whenever iCloud reports a change
    /// from another of the player's devices, so progress made on an iPad and
    /// an iPhone converges automatically without ever losing either side's data.
    private func load() {
        let localWordSearch = decode(from: defaults.data(forKey: wordSearchKey))
        let localTrivia = decode(from: defaults.data(forKey: triviaKey))
        let cloudWordSearch = decode(from: cloud.data(forKey: wordSearchKey))
        let cloudTrivia = decode(from: cloud.data(forKey: triviaKey))

        wordSearchResults = merge(localWordSearch, cloudWordSearch)
        triviaResults = merge(localTrivia, cloudTrivia)
        totalCoins = max(defaults.integer(forKey: coinsKey), Int(cloud.longLong(forKey: coinsKey)))

        persist(wordSearchResults, key: wordSearchKey)
        persist(triviaResults, key: triviaKey)
        defaults.set(totalCoins, forKey: coinsKey)
        cloud.set(Int64(totalCoins), forKey: coinsKey)
        iCloudAvailable = FileManager.default.ubiquityIdentityToken != nil
    }

    private func merge(_ a: [String: LevelResult], _ b: [String: LevelResult]) -> [String: LevelResult] {
        guard !b.isEmpty else { return a }
        var merged = a
        for (key, remote) in b {
            if let local = merged[key] {
                merged[key] = LevelResult(
                    stars: max(local.stars, remote.stars),
                    bestScore: max(local.bestScore, remote.bestScore),
                    bestTimeSeconds: min(local.bestTimeSeconds, remote.bestTimeSeconds)
                )
            } else {
                merged[key] = remote
            }
        }
        return merged
    }

    private func decode(from data: Data?) -> [String: LevelResult] {
        guard let data, let decoded = try? JSONDecoder().decode([String: LevelResult].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func key(theme: GameTheme, level: Int) -> String {
        "\(theme.id)#\(level)"
    }

    private func levels(in results: [String: LevelResult], theme: GameTheme) -> [Int] {
        let prefix = "\(theme.id)#"
        return results.keys.compactMap { k -> Int? in
            guard k.hasPrefix(prefix) else { return nil }
            return Int(k.dropFirst(prefix.count))
        }
    }

    /// Every difficulty tier's first level is always open, so players can jump
    /// straight to the difficulty they want instead of grinding earlier tiers.
    /// Levels after that within the same tier still unlock sequentially as
    /// you complete them, so choosing a tier still feels like progress.
    private func tierBand(for level: Int) -> Int {
        (level - 1) / GameMode.tierSize
    }

    private func tierRange(for band: Int) -> ClosedRange<Int> {
        let start = band * GameMode.tierSize + 1
        let end = min(start + GameMode.tierSize - 1, GameMode.levelCount)
        return start...end
    }

    func highestUnlockedLevel(for mode: GameMode, theme: GameTheme, inTier band: Int) -> Int {
        let range = tierRange(for: band)
        let results = mode == .wordSearch ? wordSearchResults : triviaResults
        let completedInTier = levels(in: results, theme: theme).filter { range.contains($0) }
        guard let maxCompleted = completedInTier.max() else { return range.lowerBound }
        return min(maxCompleted + 1, range.upperBound)
    }

    func isUnlocked(_ level: Int, mode: GameMode, theme: GameTheme) -> Bool {
        let band = tierBand(for: level)
        if level == tierRange(for: band).lowerBound { return true }
        return level <= highestUnlockedLevel(for: mode, theme: theme, inTier: band)
    }

    /// The furthest level reached overall, used only to auto-scroll the level
    /// map to a sensible "resume here" spot — it does not gate access.
    func furthestReachedLevel(for mode: GameMode, theme: GameTheme) -> Int {
        let results = mode == .wordSearch ? wordSearchResults : triviaResults
        guard let maxCompleted = levels(in: results, theme: theme).max() else { return 1 }
        return min(maxCompleted + 1, GameMode.levelCount)
    }

    func result(for level: Int, mode: GameMode, theme: GameTheme) -> LevelResult? {
        let results = mode == .wordSearch ? wordSearchResults : triviaResults
        return results[key(theme: theme, level: level)]
    }

    func themeStars(mode: GameMode, theme: GameTheme) -> Int {
        let results = mode == .wordSearch ? wordSearchResults : triviaResults
        let prefix = "\(theme.id)#"
        return results.filter { $0.key.hasPrefix(prefix) }.values.reduce(0) { $0 + $1.stars }
    }

    func themeLevelsCompleted(mode: GameMode, theme: GameTheme) -> Int {
        let results = mode == .wordSearch ? wordSearchResults : triviaResults
        let prefix = "\(theme.id)#"
        return results.keys.filter { $0.hasPrefix(prefix) }.count
    }

    func recordCompletion(level: Int, mode: GameMode, theme: GameTheme, stars: Int, score: Int, timeSeconds: Int) {
        let k = key(theme: theme, level: level)
        let existing = mode == .wordSearch ? wordSearchResults[k] : triviaResults[k]
        let bestStars = max(existing?.stars ?? 0, stars)
        let bestScore = max(existing?.bestScore ?? 0, score)
        let bestTime = existing.map { min($0.bestTimeSeconds, timeSeconds) } ?? timeSeconds
        let newResult = LevelResult(stars: bestStars, bestScore: bestScore, bestTimeSeconds: bestTime)

        if mode == .wordSearch {
            wordSearchResults[k] = newResult
            persist(wordSearchResults, key: wordSearchKey)
        } else {
            triviaResults[k] = newResult
            persist(triviaResults, key: triviaKey)
        }

        let earnedCoins = stars * 10 + (existing == nil ? 20 : 0)
        totalCoins += earnedCoins
        defaults.set(totalCoins, forKey: coinsKey)
        cloud.set(Int64(totalCoins), forKey: coinsKey)
        cloud.synchronize()

        reportToGameCenter(mode: mode, isFirstCompletion: existing == nil)
    }

    private func reportToGameCenter(mode: GameMode, isFirstCompletion: Bool) {
        let leaderboardID = mode == .wordSearch ? GameCenterManager.LeaderboardID.wordSearchTotalScore : GameCenterManager.LeaderboardID.triviaTotalScore
        let modeTotal = mode == .wordSearch ? wordSearchTotalScore : triviaTotalScore
        GameCenterManager.shared.submitScore(modeTotal, leaderboardID: leaderboardID)
        GameCenterManager.shared.submitScore(totalStars, leaderboardID: GameCenterManager.LeaderboardID.totalStars)

        if isFirstCompletion {
            GameCenterManager.shared.reportAchievement(GameCenterManager.AchievementID.firstWin)
        }
        GameCenterManager.shared.reportAchievement(
            GameCenterManager.AchievementID.hundredLevels,
            percentComplete: min(100, Double(levelsCompleted))
        )
    }

    var wordSearchTotalScore: Int {
        wordSearchResults.values.reduce(0) { $0 + $1.bestScore }
    }

    var triviaTotalScore: Int {
        triviaResults.values.reduce(0) { $0 + $1.bestScore }
    }

    private func persist(_ results: [String: LevelResult], key: String) {
        guard let data = try? JSONEncoder().encode(results) else { return }
        defaults.set(data, forKey: key)
        if data.count < iCloudValueSizeLimit {
            cloud.set(data, forKey: key)
            cloud.synchronize()
        }
    }

    var totalStars: Int {
        wordSearchResults.values.reduce(0) { $0 + $1.stars } +
        triviaResults.values.reduce(0) { $0 + $1.stars }
    }

    var levelsCompleted: Int {
        wordSearchResults.count + triviaResults.count
    }

    #if DEBUG
    func resetAll() {
        wordSearchResults = [:]
        triviaResults = [:]
        totalCoins = 0
        defaults.removeObject(forKey: wordSearchKey)
        defaults.removeObject(forKey: triviaKey)
        defaults.removeObject(forKey: coinsKey)
        cloud.removeObject(forKey: wordSearchKey)
        cloud.removeObject(forKey: triviaKey)
        cloud.removeObject(forKey: coinsKey)
        cloud.synchronize()
    }
    #endif
}
