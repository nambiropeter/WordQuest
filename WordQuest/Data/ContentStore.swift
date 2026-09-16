import Foundation

final class ContentStore {
    static let shared = ContentStore()

    let themes: [GameTheme]
    private let wordsByTheme: [String: [String]]
    private let questionsByTheme: [String: [TriviaQuestionData]]

    private init() {
        let loadedThemes: [GameTheme] = ContentStore.load("themes")
        self.themes = loadedThemes

        var words: [String: [String]] = [:]
        var questions: [String: [TriviaQuestionData]] = [:]
        for theme in loadedThemes {
            words[theme.id] = ContentStore.load("words_\(theme.id)")
            questions[theme.id] = ContentStore.load("trivia_\(theme.id)")
        }
        self.wordsByTheme = words
        self.questionsByTheme = questions
    }

    func words(for themeID: String) -> [String] {
        wordsByTheme[themeID] ?? []
    }

    func questions(for themeID: String) -> [TriviaQuestionData] {
        questionsByTheme[themeID] ?? []
    }

    func theme(id: String) -> GameTheme {
        themes.first { $0.id == id } ?? themes[0]
    }

    private static func load<T: Decodable>(_ filename: String) -> T {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
            fatalError("Missing bundled content file: \(filename).json")
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            fatalError("Failed to decode \(filename).json: \(error)")
        }
    }
}
