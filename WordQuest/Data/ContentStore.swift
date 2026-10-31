import Foundation

/// Loads `themes.json` and the per-theme `words_*.json` / `trivia_*.json`
/// files bundled with the app.
///
/// Every load is defensive: a missing or malformed content file degrades to
/// an empty list rather than trapping. This is constructed eagerly and from
/// a `static let`, so a `fatalError` here would be a launch crash with no
/// recovery path — an empty theme or word list is recoverable, a dead app
/// is not.
final class ContentStore {
    static let shared = ContentStore()

    /// Used only if `themes.json` is missing, corrupt, or empty, so screens
    /// that assume a non-empty theme list have something to render.
    static let fallbackTheme = GameTheme(
        id: "mixed",
        name: "Mixed",
        icon: "sparkles",
        colorPrimary: "#7209B7",
        colorSecondary: "#EF476F"
    )

    let themes: [GameTheme]
    private let wordsByTheme: [String: [String]]
    private let questionsByTheme: [String: [TriviaQuestionData]]

    private init() {
        let loadedThemes: [GameTheme] = ContentStore.load("themes", fallback: [])
        self.themes = loadedThemes

        var words: [String: [String]] = [:]
        var questions: [String: [TriviaQuestionData]] = [:]
        for theme in loadedThemes {
            words[theme.id] = ContentStore.load("words_\(theme.id)", fallback: [])
            questions[theme.id] = ContentStore.load("trivia_\(theme.id)", fallback: [])
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
        themes.first { $0.id == id } ?? themes.first ?? Self.fallbackTheme
    }

    private static func load<T: Decodable>(_ filename: String, fallback: T) -> T {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
            print("ContentStore: missing bundled content file \(filename).json, falling back")
            return fallback
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("ContentStore: failed to decode \(filename).json (\(error)), falling back")
            return fallback
        }
    }
}
