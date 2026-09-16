import Foundation

enum GridDirection: CaseIterable {
    case right, left, down, up, downRight, downLeft, upRight, upLeft

    var delta: (dr: Int, dc: Int) {
        switch self {
        case .right: return (0, 1)
        case .left: return (0, -1)
        case .down: return (1, 0)
        case .up: return (-1, 0)
        case .downRight: return (1, 1)
        case .downLeft: return (1, -1)
        case .upRight: return (-1, 1)
        case .upLeft: return (-1, -1)
        }
    }
}

struct GridPosition: Hashable, Equatable {
    let row: Int
    let col: Int
}

struct PlacedWord: Identifiable, Equatable {
    let id = UUID()
    let word: String
    let path: [GridPosition]
    var isFound: Bool = false
}

struct WordSearchPuzzle {
    let levelIndex: Int
    let theme: GameTheme
    let gridSize: Int
    let letters: [[Character]]
    var placedWords: [PlacedWord]
    let hintsAllowed: Int
}
