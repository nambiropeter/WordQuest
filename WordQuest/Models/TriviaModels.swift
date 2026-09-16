import Foundation

enum TriviaDifficulty: String, Codable {
    case easy, medium, hard

    var points: Int {
        switch self {
        case .easy: return 100
        case .medium: return 150
        case .hard: return 200
        }
    }
}

struct TriviaQuestionData: Codable {
    let q: String
    let options: [String]
    let answer: Int
    let difficulty: TriviaDifficulty
}

struct TriviaQuestion: Identifiable {
    let id = UUID()
    let text: String
    let options: [String]
    let correctIndex: Int
    let difficulty: TriviaDifficulty
}

struct TriviaLevel {
    let levelIndex: Int
    let theme: GameTheme
    let questions: [TriviaQuestion]
    let timePerQuestion: Int
}
