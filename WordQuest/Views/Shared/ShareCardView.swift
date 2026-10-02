import SwiftUI

/// What gets drawn on the shareable result image — either a solo level
/// result or a local multiplayer finish.
enum ShareCard: Hashable {
    case level(score: Int, stars: Int, level: Int, theme: GameTheme, mode: GameMode)
    case multiplayer(rank: Int, scores: [PlayerScore], myID: String)

    var caption: String {
        switch self {
        case let .level(score, _, level, theme, mode):
            return "I just scored \(score) points on Level \(level) (\(theme.name)) in \(mode.displayName) on WordQuest! 🧩"
        case let .multiplayer(rank, scores, myID):
            let myScore = scores.first { $0.id == myID }?.score ?? 0
            return "I just finished #\(rank) of \(scores.count) with \(myScore) points in a WordQuest local multiplayer trivia game! 🏆"
        }
    }

    /// Renders the card to a 1080 × 1350 (4:5) image for the share sheet.
    @MainActor
    func render() -> Image? {
        let renderer = ImageRenderer(content: ShareCardView(card: self))
        renderer.scale = 3
        return renderer.uiImage.map { Image(uiImage: $0) }
    }
}

/// The 360 × 450 pt result card shared as an image. Android's `ShareCard.kt`
/// draws the same layout so a card from either platform looks like the same game.
struct ShareCardView: View {
    let card: ShareCard

    static let size = CGSize(width: 360, height: 450)
    private static let gold = Color(hex: "#FFD166")

    var body: some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            letterGrid
            RadialGradient(colors: [.white.opacity(0.22), .clear], center: UnitPoint(x: 0.5, y: 250 / 450), startRadius: 0, endRadius: 170)

            VStack(spacing: 0) {
                brandPill
                    .padding(.top, 24)

                Circle()
                    .fill(.white.opacity(0.22))
                    .frame(width: 56, height: 56)
                    .overlay(Image(systemName: heroSymbol).font(.system(size: 24, weight: .bold)))
                    .padding(.top, 16)

                switch card {
                case let .level(score, stars, level, theme, mode):
                    levelBody(score: score, stars: stars, level: level, theme: theme, mode: mode)
                case let .multiplayer(rank, scores, myID):
                    multiplayerBody(rank: rank, scores: scores, myID: myID)
                }

                Spacer(minLength: 0)

                Text("Can you beat my score?")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                Text("Play WordQuest · free on iOS & Android")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .opacity(0.75)
                    .padding(.top, 3)
                    .padding(.bottom, 24)
            }
            .foregroundStyle(.white)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    private var colors: [Color] {
        switch card {
        case let .level(_, _, _, theme, _): return [theme.primaryColor, theme.secondaryColor]
        case .multiplayer: return [Color(hex: "#118AB2"), Color(hex: "#073B4C")]
        }
    }

    private var heroSymbol: String {
        switch card {
        case let .level(_, _, _, theme, _): return theme.icon
        case .multiplayer: return "trophy.fill"
        }
    }

    // MARK: - Bodies

    private func levelBody(score: Int, stars: Int, level: Int, theme: GameTheme, mode: GameMode) -> some View {
        VStack(spacing: 0) {
            Text("LEVEL COMPLETE!")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .tracking(1)
                .padding(.top, 14)

            // Middle star raised, like the in-game result.
            HStack(spacing: 12) {
                ForEach(0..<3) { i in
                    Image(systemName: "star.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(i < stars ? Self.gold : .white.opacity(0.28))
                        .offset(y: i == 1 ? -8 : 0)
                }
            }
            .padding(.top, 18)

            Text("\(score)")
                .font(.system(size: 80, weight: .black, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(.horizontal, 24)
            Text("POINTS")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(3.6)
                .opacity(0.75)

            chip("LEVEL \(level)  ·  \(theme.name.uppercased())  ·  \(mode.displayName.uppercased())")
                .padding(.top, 14)
        }
    }

    private func multiplayerBody(rank: Int, scores: [PlayerScore], myID: String) -> some View {
        let myScore = scores.first { $0.id == myID }?.score ?? 0
        let medals = [Self.gold, Color(hex: "#D9D9D9"), Color(hex: "#D4A373")]
        return VStack(spacing: 0) {
            Text(rank == 1 ? "WINNER!" : "FINISHED #\(rank)")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .tracking(1)
                .padding(.top, 14)
            Text("of \(scores.count) players · Local Trivia")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .opacity(0.75)
                .padding(.top, 2)

            Text("\(myScore)")
                .font(.system(size: 64, weight: .black, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(.horizontal, 24)
            Text("POINTS")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(3.6)
                .opacity(0.75)

            // Mini podium: top three, with the sharer's row highlighted (swapped in for #3 if they placed lower).
            VStack(spacing: 0) {
                ForEach(podiumRows(scores: scores, myID: myID), id: \.element.id) { index, entry in
                    let mine = entry.id == myID
                    HStack(spacing: 8) {
                        Text("\(index + 1)")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(Color(hex: "#073B4C"))
                            .frame(width: 18, height: 18)
                            .background(index < medals.count ? medals[index] : .white.opacity(0.6), in: Circle())
                        Text(entry.name)
                            .font(.system(size: 14, weight: mine ? .black : .semibold, design: .rounded))
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text("\(entry.score)")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(mine ? .white.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(6)
            .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 48)
            .padding(.top, 10)
        }
    }

    private func podiumRows(scores: [PlayerScore], myID: String) -> [(offset: Int, element: PlayerScore)] {
        let ranked = Array(scores.enumerated())
        let top = Array(ranked.prefix(3))
        guard !top.contains(where: { $0.element.id == myID }),
              let mine = ranked.first(where: { $0.element.id == myID }) else { return top }
        return Array(top.prefix(2)) + [mine]
    }

    // MARK: - Pieces

    private var brandPill: some View {
        HStack(spacing: 6) {
            Image(systemName: "square.grid.3x3.fill")
                .font(.system(size: 13, weight: .bold))
            Text("WORDQUEST")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .tracking(2.3)
        }
        .padding(.horizontal, 14)
        .frame(height: 30)
        .background(.white.opacity(0.18), in: Capsule())
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .tracking(0.7)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .frame(height: 28)
            .background(.white.opacity(0.16), in: Capsule())
            .padding(.horizontal, 32)
    }

    /// Faint word-search letters filling the background so the card reads as WordQuest at a glance.
    private var letterGrid: some View {
        var rng = SeededLetters(seed: UInt64(truncatingIfNeeded: card.hashValue))
        let letters = (0..<80).map { _ in rng.nextLetter() }
        let cell = Self.size.width / 8
        return VStack(spacing: 0) {
            ForEach(0..<10, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { c in
                        Text(letters[r * 8 + c])
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(.white.opacity(0.07))
                            .frame(width: cell, height: cell)
                    }
                }
            }
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .top)
    }
}

/// Tiny xorshift so the background letters stay put across re-renders.
private struct SeededLetters {
    var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func nextLetter() -> String {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return String(UnicodeScalar(UInt8(65 + state % 26)))
    }
}

/// Share button that hands the rendered card image (plus caption) to the share sheet.
struct ShareCardButton<Label: View>: View {
    let card: ShareCard
    @ViewBuilder let label: () -> Label

    @State private var image: Image?

    var body: some View {
        Group {
            if let image {
                ShareLink(
                    item: image,
                    subject: Text("My WordQuest result"),
                    message: Text(card.caption),
                    preview: SharePreview("My WordQuest result", image: image),
                    label: label
                )
            } else {
                label().opacity(0.5)
            }
        }
        .task(id: card) { image = card.render() }
    }
}

#Preview("Level") {
    ShareCardView(card: .level(
        score: 1240, stars: 3, level: 12,
        theme: GameTheme(id: "animals", name: "Animals", icon: "pawprint.fill", colorPrimary: "#F4A261", colorSecondary: "#E76F51"),
        mode: .wordSearch
    ))
}

#Preview("Multiplayer") {
    ShareCardView(card: .multiplayer(rank: 1, scores: [
        PlayerScore(id: "a", name: "Anthony", score: 820, correctCount: 8),
        PlayerScore(id: "b", name: "Sam", score: 640, correctCount: 6),
        PlayerScore(id: "c", name: "Jordan", score: 300, correctCount: 3),
    ], myID: "a"))
}
