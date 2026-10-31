import Foundation

struct PlayerInfo: Codable, Identifiable, Hashable {
    let id: String
    let name: String
}

struct PlayerScore: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    var score: Int
    var correctCount: Int
}

struct NetworkQuestion: Codable, Hashable {
    let text: String
    let options: [String]
}

/// The wire protocol for local multiplayer trivia, shared byte-for-byte with
/// Android's `MultiplayerMessage` so iPhones and Android phones can play
/// together. The host is authoritative: it owns the correct answers, paces
/// questions, scores submissions, and broadcasts state to every connected peer.
///
/// Each message is a flat JSON object whose `"type"` field names the case, e.g.
/// `{"type":"answer","playerId":"…","questionIndex":2,"answerIndex":1,"elapsedMs":4200}`.
/// Swift's synthesized enum coding produces a different, nested shape, so the
/// coding is written out by hand below; renaming a case or key here means
/// changing the Android `@SerialName`s and property names to match.
enum MultiplayerMessage: Codable {
    case hello(PlayerInfo)
    case lobbyState(players: [PlayerInfo], hostID: String, questionCount: Int)
    case gameStart(questions: [NetworkQuestion], timePerQuestion: Int, theme: GameTheme)
    case questionStart(index: Int)
    case answer(playerID: String, questionIndex: Int, answerIndex: Int, elapsedMs: Int)
    case questionResult(index: Int, correctIndex: Int, scores: [PlayerScore])
    case gameOver(scores: [PlayerScore])
    case playerLeft(playerID: String)

    private enum CodingKeys: String, CodingKey {
        case type, player, players, hostId, questionCount, questions, timePerQuestion, theme
        case index, playerId, questionIndex, answerIndex, elapsedMs, correctIndex, scores
    }

    private enum Kind: String, Codable {
        case hello, lobbyState, gameStart, questionStart, answer, questionResult, gameOver, playerLeft
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .type) {
        case .hello:
            self = .hello(try c.decode(PlayerInfo.self, forKey: .player))
        case .lobbyState:
            self = .lobbyState(
                players: try c.decode([PlayerInfo].self, forKey: .players),
                hostID: try c.decode(String.self, forKey: .hostId),
                questionCount: try c.decode(Int.self, forKey: .questionCount)
            )
        case .gameStart:
            self = .gameStart(
                questions: try c.decode([NetworkQuestion].self, forKey: .questions),
                timePerQuestion: try c.decode(Int.self, forKey: .timePerQuestion),
                theme: try c.decode(GameTheme.self, forKey: .theme)
            )
        case .questionStart:
            self = .questionStart(index: try c.decode(Int.self, forKey: .index))
        case .answer:
            self = .answer(
                playerID: try c.decode(String.self, forKey: .playerId),
                questionIndex: try c.decode(Int.self, forKey: .questionIndex),
                answerIndex: try c.decode(Int.self, forKey: .answerIndex),
                elapsedMs: try c.decode(Int.self, forKey: .elapsedMs)
            )
        case .questionResult:
            self = .questionResult(
                index: try c.decode(Int.self, forKey: .index),
                correctIndex: try c.decode(Int.self, forKey: .correctIndex),
                scores: try c.decode([PlayerScore].self, forKey: .scores)
            )
        case .gameOver:
            self = .gameOver(scores: try c.decode([PlayerScore].self, forKey: .scores))
        case .playerLeft:
            self = .playerLeft(playerID: try c.decode(String.self, forKey: .playerId))
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .hello(let player):
            try c.encode(Kind.hello, forKey: .type)
            try c.encode(player, forKey: .player)
        case .lobbyState(let players, let hostID, let questionCount):
            try c.encode(Kind.lobbyState, forKey: .type)
            try c.encode(players, forKey: .players)
            try c.encode(hostID, forKey: .hostId)
            try c.encode(questionCount, forKey: .questionCount)
        case .gameStart(let questions, let timePerQuestion, let theme):
            try c.encode(Kind.gameStart, forKey: .type)
            try c.encode(questions, forKey: .questions)
            try c.encode(timePerQuestion, forKey: .timePerQuestion)
            try c.encode(theme, forKey: .theme)
        case .questionStart(let index):
            try c.encode(Kind.questionStart, forKey: .type)
            try c.encode(index, forKey: .index)
        case .answer(let playerID, let questionIndex, let answerIndex, let elapsedMs):
            try c.encode(Kind.answer, forKey: .type)
            try c.encode(playerID, forKey: .playerId)
            try c.encode(questionIndex, forKey: .questionIndex)
            try c.encode(answerIndex, forKey: .answerIndex)
            try c.encode(elapsedMs, forKey: .elapsedMs)
        case .questionResult(let index, let correctIndex, let scores):
            try c.encode(Kind.questionResult, forKey: .type)
            try c.encode(index, forKey: .index)
            try c.encode(correctIndex, forKey: .correctIndex)
            try c.encode(scores, forKey: .scores)
        case .gameOver(let scores):
            try c.encode(Kind.gameOver, forKey: .type)
            try c.encode(scores, forKey: .scores)
        case .playerLeft(let playerID):
            try c.encode(Kind.playerLeft, forKey: .type)
            try c.encode(playerID, forKey: .playerId)
        }
    }
}
