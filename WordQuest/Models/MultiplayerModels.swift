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

/// The wire protocol for local multiplayer trivia. The host is authoritative:
/// it owns the correct answers, paces questions, scores submissions, and
/// broadcasts state to every connected peer over MultipeerConnectivity
/// (which transparently uses Bluetooth or peer-to-peer / local Wi-Fi,
/// whichever link is available between the devices).
enum MultiplayerMessage: Codable {
    case hello(PlayerInfo)
    case lobbyState(players: [PlayerInfo], hostID: String, questionCount: Int)
    case gameStart(questions: [NetworkQuestion], timePerQuestion: Int, theme: GameTheme)
    case questionStart(index: Int)
    case answer(playerID: String, questionIndex: Int, answerIndex: Int, elapsedMs: Int)
    case questionResult(index: Int, correctIndex: Int, scores: [PlayerScore])
    case gameOver(scores: [PlayerScore])
    case playerLeft(playerID: String)
}
