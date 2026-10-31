import SwiftUI

@MainActor
final class MultiplayerViewModel: ObservableObject {
    enum Role { case undecided, host, client }
    enum Phase { case roleSelect, browsing, lobby, playing, results }

    /// Host + guests per session.
    static let maxPlayers = MultiplayerService.maxPeers

    @Published var phase: Phase = .roleSelect
    @Published private(set) var role: Role = .undecided
    @Published var playerName: String
    @Published private(set) var players: [PlayerInfo] = []
    @Published private(set) var discoveredHosts: [MultiplayerService.DiscoveredHost] = []
    @Published var connectingToHost: MultiplayerService.DiscoveredHost?

    @Published var selectedTheme: GameTheme?
    @Published var questionCount: Int = 8

    @Published private(set) var questions: [NetworkQuestion] = []
    @Published private(set) var currentIndex = 0
    @Published private(set) var timePerQuestion = 15
    @Published private(set) var timeRemaining = 15
    @Published private(set) var selectedAnswer: Int?
    @Published private(set) var hasAnswered = false
    @Published private(set) var revealedCorrectIndex: Int?
    @Published private(set) var scores: [PlayerScore] = []
    @Published private(set) var themeForGame: GameTheme?

    let myID: String
    private var service: MultiplayerService?
    private var fullQuestions: [TriviaQuestion] = []
    private var answersThisQuestion: [String: (index: Int, elapsedMs: Int)] = [:]
    private var questionStartedAt: Date?
    private var timer: Timer?
    private var cumulativeScores: [String: PlayerScore] = [:]
    private var peerIDMap: [MultiplayerService.Peer: String] = [:]
    private var isResolvingQuestion = false

    init() {
        if let stored = UserDefaults.standard.string(forKey: "wq.player.id") {
            myID = stored
        } else {
            let new = UUID().uuidString
            UserDefaults.standard.set(new, forKey: "wq.player.id")
            myID = new
        }
        #if os(iOS)
        playerName = UserDefaults.standard.string(forKey: "wq.player.name") ?? UIDevice.current.name
        #else
        playerName = UserDefaults.standard.string(forKey: "wq.player.name") ?? "Player"
        #endif
    }

    func updatePlayerName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        playerName = trimmed.isEmpty ? "Player" : trimmed
        UserDefaults.standard.set(playerName, forKey: "wq.player.name")
    }

    private func setupService() {
        let s = MultiplayerService(displayName: "\(playerName)#\(myID.prefix(4))")
        s.onPeerConnected = { [weak self] peer in self?.handlePeerConnected(peer) }
        s.onPeerDisconnected = { [weak self] peer in self?.handlePeerDisconnected(peer) }
        s.onReceive = { [weak self] message, peer in self?.handleMessage(message, from: peer) }
        s.onHostDiscovered = { [weak self] host in
            guard let self, !self.discoveredHosts.contains(where: { $0.id == host.id }) else { return }
            self.discoveredHosts.append(host)
        }
        s.onHostLost = { [weak self] host in
            self?.discoveredHosts.removeAll { $0.id == host.id }
        }
        service = s
    }

    // MARK: - Host

    func startHosting() {
        role = .host
        setupService()
        service?.startHosting()
        players = [PlayerInfo(id: myID, name: playerName)]
        phase = .lobby
    }

    func startGame() {
        guard role == .host, let service else { return }
        let theme = selectedTheme ?? ContentStore.fallbackTheme
        let qs = LevelCatalog.randomQuestions(theme: selectedTheme, count: questionCount)
        guard !qs.isEmpty else { return }
        fullQuestions = qs
        themeForGame = theme
        questions = qs.map { NetworkQuestion(text: $0.text, options: $0.options) }
        timePerQuestion = 15
        cumulativeScores = Dictionary(uniqueKeysWithValues: players.map { ($0.id, PlayerScore(id: $0.id, name: $0.name, score: 0, correctCount: 0)) })

        service.send(.gameStart(questions: questions, timePerQuestion: timePerQuestion, theme: theme))
        phase = .playing
        beginQuestion(0)
    }

    private func beginQuestion(_ index: Int) {
        isResolvingQuestion = false
        currentIndex = index
        selectedAnswer = nil
        hasAnswered = false
        revealedCorrectIndex = nil
        answersThisQuestion = [:]
        questionStartedAt = Date()
        timeRemaining = timePerQuestion
        service?.send(.questionStart(index: index))
        startLocalTimer()
    }

    private func startLocalTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.timeRemaining > 0 {
                    self.timeRemaining -= 1
                } else {
                    self.timer?.invalidate()
                    if self.role == .host { self.finishQuestion() }
                }
            }
        }
    }

    private func finishQuestion() {
        guard role == .host, currentIndex < fullQuestions.count else { return }
        // The last answer arriving and the timer expiring can both land on the
        // same question; without this the round would be scored twice and the
        // 3-second advance scheduled twice, skipping a question.
        guard !isResolvingQuestion else { return }
        isResolvingQuestion = true
        timer?.invalidate()
        let correctIndex = fullQuestions[currentIndex].correctIndex
        let points = fullQuestions[currentIndex].difficulty.points

        for player in players {
            guard var score = cumulativeScores[player.id] else { continue }
            if let answer = answersThisQuestion[player.id], answer.index == correctIndex {
                let remainingMs = max(0, timePerQuestion * 1000 - answer.elapsedMs)
                score.score += points + (remainingMs / 1000) * 5
                score.correctCount += 1
            }
            cumulativeScores[player.id] = score
        }

        let scoresArray = Array(cumulativeScores.values).sorted { $0.score > $1.score }
        scores = scoresArray
        revealedCorrectIndex = correctIndex
        service?.send(.questionResult(index: currentIndex, correctIndex: correctIndex, scores: scoresArray))

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self else { return }
            let next = self.currentIndex + 1
            if next >= self.fullQuestions.count {
                self.service?.send(.gameOver(scores: scoresArray))
                self.phase = .results
                self.checkChampionAchievement(scoresArray)
            } else {
                self.beginQuestion(next)
            }
        }
    }

    private func hostReceivedAnswer(playerID: String, questionIndex: Int, answerIndex: Int) {
        guard role == .host, questionIndex == currentIndex else { return }
        // Elapsed time is derived from the host's own receipt clock rather than
        // trusting the peer-reported value, since a modified client could
        // otherwise always claim elapsedMs = 0 for the maximum speed bonus.
        let elapsed = Date().timeIntervalSince(questionStartedAt ?? Date())
        let elapsedMs = min(max(Int(elapsed * 1000), 0), timePerQuestion * 1000)
        answersThisQuestion[playerID] = (answerIndex, elapsedMs)
        if answersThisQuestion.count >= players.count {
            finishQuestion()
        }
    }

    // MARK: - Client

    func startBrowsing() {
        role = .client
        setupService()
        service?.startBrowsing()
        phase = .browsing
    }

    func joinHost(_ host: MultiplayerService.DiscoveredHost) {
        connectingToHost = host
        service?.connect(to: host)
    }

    // MARK: - Shared

    func selectAnswer(_ index: Int) {
        guard !hasAnswered else { return }
        hasAnswered = true
        selectedAnswer = index
        if role == .host {
            hostReceivedAnswer(playerID: myID, questionIndex: currentIndex, answerIndex: index)
        } else {
            let elapsedMs = Int(Date().timeIntervalSince(questionStartedAt ?? Date()) * 1000)
            service?.send(.answer(playerID: myID, questionIndex: currentIndex, answerIndex: index, elapsedMs: elapsedMs))
        }
    }

    private func handlePeerConnected(_ peer: MultiplayerService.Peer) {
        service?.send(.hello(PlayerInfo(id: myID, name: playerName)), to: [peer])
        if role == .host {
            broadcastLobby()
        }
    }

    private func handlePeerDisconnected(_ peer: MultiplayerService.Peer) {
        guard let id = peerIDMap[peer] else { return }
        players.removeAll { $0.id == id }
        peerIDMap[peer] = nil
        if role == .host {
            broadcastLobby()
        }
    }

    private func broadcastLobby() {
        service?.send(.lobbyState(players: players, hostID: myID, questionCount: questionCount))
    }

    private func handleMessage(_ message: MultiplayerMessage, from peer: MultiplayerService.Peer) {
        switch message {
        case .hello(let info):
            peerIDMap[peer] = info.id
            if role == .host, !players.contains(where: { $0.id == info.id }) {
                players.append(info)
                // Defensive: if this hello arrives after startGame() already
                // snapshotted cumulativeScores, seed an entry so a mid-game
                // (re)join isn't silently unscored for the rest of the round.
                if cumulativeScores[info.id] == nil {
                    cumulativeScores[info.id] = PlayerScore(id: info.id, name: info.name, score: 0, correctCount: 0)
                }
                broadcastLobby()
            }
        case .lobbyState(let ps, _, let count):
            guard role == .client else { return }
            players = ps
            questionCount = count
            phase = .lobby
        case .gameStart(let qs, let time, let theme):
            questions = qs
            timePerQuestion = time
            themeForGame = theme
            phase = .playing
        case .questionStart(let index):
            currentIndex = index
            selectedAnswer = nil
            hasAnswered = false
            revealedCorrectIndex = nil
            questionStartedAt = Date()
            timeRemaining = timePerQuestion
            startLocalTimer()
        case .answer(let playerID, let qIndex, let answerIndex, _):
            hostReceivedAnswer(playerID: playerID, questionIndex: qIndex, answerIndex: answerIndex)
        case .questionResult(let index, let correctIndex, let newScores):
            guard index == currentIndex else { return }
            revealedCorrectIndex = correctIndex
            scores = newScores
        case .gameOver(let finalScores):
            scores = finalScores
            phase = .results
            checkChampionAchievement(finalScores)
        case .playerLeft(let id):
            players.removeAll { $0.id == id }
        }
    }

    private func checkChampionAchievement(_ finalScores: [PlayerScore]) {
        guard finalScores.count > 1, finalScores.first?.id == myID else { return }
        GameCenterManager.shared.reportAchievement(GameCenterManager.AchievementID.multiplayerChampion)
    }

    var isHost: Bool { role == .host }
    var myScore: PlayerScore? { scores.first { $0.id == myID } }
    var myRank: Int? {
        guard let idx = scores.firstIndex(where: { $0.id == myID }) else { return nil }
        return idx + 1
    }
    var currentQuestion: NetworkQuestion? {
        currentIndex < questions.count ? questions[currentIndex] : nil
    }
    var totalQuestions: Int { questions.count }
    var connectedCount: Int { players.count }

    func leaveGame() {
        timer?.invalidate()
        service?.disconnect()
        service = nil
        phase = .roleSelect
        role = .undecided
        players = []
        scores = []
        questions = []
        discoveredHosts = []
        peerIDMap = [:]
        answersThisQuestion = [:]
        cumulativeScores = [:]
        isResolvingQuestion = false
    }

    deinit {
        timer?.invalidate()
    }
}
