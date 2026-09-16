import SwiftUI
import Combine

@MainActor
final class WordSearchViewModel: ObservableObject {
    @Published private(set) var puzzle: WordSearchPuzzle
    @Published private(set) var currentSelection: [GridPosition] = []
    @Published private(set) var foundPaths: [[GridPosition]] = []
    @Published private(set) var hintedPosition: GridPosition?
    @Published private(set) var hintsRemaining: Int
    @Published private(set) var elapsedSeconds: Int = 0
    @Published private(set) var isComplete = false
    @Published var lastFoundWasCorrect: Bool?

    private var dragStart: GridPosition?
    private var timer: Timer?
    let level: Int
    let theme: GameTheme

    init(theme: GameTheme, level: Int) {
        self.theme = theme
        self.level = level
        let p = LevelCatalog.wordSearchLevel(theme: theme, level: level)
        self.puzzle = p
        self.hintsRemaining = p.hintsAllowed
    }

    var totalWords: Int { puzzle.placedWords.count }
    var foundCount: Int { puzzle.placedWords.filter { $0.isFound }.count }
    var progress: Double { totalWords == 0 ? 0 : Double(foundCount) / Double(totalWords) }

    func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.elapsedSeconds += 1
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func beginSelection(at position: GridPosition) {
        dragStart = position
        currentSelection = [position]
    }

    func updateSelection(to position: GridPosition) {
        guard let start = dragStart else { return }
        currentSelection = Self.straightLine(from: start, to: position) ?? [start]
    }

    func endSelection() {
        defer {
            dragStart = nil
            currentSelection = []
        }
        guard currentSelection.count > 1 else { return }
        checkSelection(currentSelection)
    }

    private func checkSelection(_ selection: [GridPosition]) {
        for (index, placed) in puzzle.placedWords.enumerated() where !placed.isFound {
            if placed.path == selection || placed.path == selection.reversed() {
                puzzle.placedWords[index].isFound = true
                foundPaths.append(placed.path)
                lastFoundWasCorrect = true
                SoundManager.wordFound()
                Haptics.success()
                checkCompletion()
                return
            }
        }
        lastFoundWasCorrect = false
        Haptics.error()
    }

    func useHint() {
        guard hintsRemaining > 0 else { return }
        guard let target = puzzle.placedWords.first(where: { !$0.isFound }) else { return }
        hintsRemaining -= 1
        hintedPosition = target.path.first
        Haptics.light()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.hintedPosition = nil
        }
    }

    private func checkCompletion() {
        guard foundCount == totalWords, totalWords > 0 else { return }
        isComplete = true
        stopTimer()
        SoundManager.levelComplete()
        HapticsPlayer.shared.playLevelComplete()

        let stars = computeStars()
        ProgressStore.shared.recordCompletion(
            level: level,
            mode: .wordSearch,
            theme: theme,
            stars: stars,
            score: foundCount * 100 + hintsRemaining * 20,
            timeSeconds: elapsedSeconds
        )
    }

    func computeStars() -> Int {
        let parTime = 20 + totalWords * 15
        let usedHints = puzzle.hintsAllowed - hintsRemaining
        if elapsedSeconds <= parTime && usedHints == 0 { return 3 }
        if elapsedSeconds <= parTime * 2 { return 2 }
        return 1
    }

    static func straightLine(from start: GridPosition, to end: GridPosition) -> [GridPosition]? {
        let dr = end.row - start.row
        let dc = end.col - start.col
        guard dr != 0 || dc != 0 else { return [start] }
        guard dr == 0 || dc == 0 || abs(dr) == abs(dc) else { return nil }

        let steps = max(abs(dr), abs(dc))
        let stepR = dr == 0 ? 0 : dr / abs(dr)
        let stepC = dc == 0 ? 0 : dc / abs(dc)

        return (0...steps).map { i in
            GridPosition(row: start.row + stepR * i, col: start.col + stepC * i)
        }
    }
}
