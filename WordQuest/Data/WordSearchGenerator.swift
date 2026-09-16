import Foundation

enum WordSearchGenerator {
    /// Places `words` into a `gridSize` x `gridSize` grid using deterministic RNG,
    /// trying all 8 directions with overlap support, then fills remaining cells.
    static func generate(words: [String], gridSize: Int, seed: Int) -> ([[Character]], [PlacedWord]) {
        var rng = SeededGenerator(seed: seed)
        var grid: [[Character?]] = Array(repeating: Array(repeating: nil, count: gridSize), count: gridSize)
        var placed: [PlacedWord] = []

        let sortedWords = words.filter { $0.count <= gridSize }.sorted { $0.count > $1.count }

        for word in sortedWords {
            if let path = tryPlace(word: word, in: &grid, gridSize: gridSize, rng: &rng) {
                placed.append(PlacedWord(word: word, path: path))
            }
        }

        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        for r in 0..<gridSize {
            for c in 0..<gridSize {
                if grid[r][c] == nil {
                    grid[r][c] = alphabet.randomElement(using: &rng)
                }
            }
        }

        let finalGrid: [[Character]] = grid.map { row in row.map { $0 ?? "?" } }
        return (finalGrid, placed)
    }

    private static func tryPlace(
        word: String,
        in grid: inout [[Character?]],
        gridSize: Int,
        rng: inout SeededGenerator
    ) -> [GridPosition]? {
        let letters = Array(word)
        let maxAttempts = 200

        for _ in 0..<maxAttempts {
            guard let direction = GridDirection.allCases.randomElement(using: &rng) else { return nil }
            let (dr, dc) = direction.delta
            let startRow = Int.random(in: 0..<gridSize, using: &rng)
            let startCol = Int.random(in: 0..<gridSize, using: &rng)

            let endRow = startRow + dr * (letters.count - 1)
            let endCol = startCol + dc * (letters.count - 1)
            guard endRow >= 0, endRow < gridSize, endCol >= 0, endCol < gridSize else { continue }

            var positions: [GridPosition] = []
            var fits = true
            for i in 0..<letters.count {
                let r = startRow + dr * i
                let c = startCol + dc * i
                if let existing = grid[r][c], existing != letters[i] {
                    fits = false
                    break
                }
                positions.append(GridPosition(row: r, col: c))
            }

            if fits {
                for (i, pos) in positions.enumerated() {
                    grid[pos.row][pos.col] = letters[i]
                }
                return positions
            }
        }
        return nil
    }
}
