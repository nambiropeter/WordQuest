import SwiftUI

struct ResultOverlay: View {
    let stars: Int
    let score: Int
    let theme: GameTheme
    let level: Int
    let mode: GameMode
    let onReplay: () -> Void
    let onNext: () -> Void
    let onHome: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var hasNextLevel: Bool { level < GameMode.levelCount }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 20) {
                Text(stars > 0 ? "Level Complete!" : "Time's Up")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)

                AnimatedStarsView(filled: stars)
                    .padding(.vertical, 4)

                VStack(spacing: 4) {
                    Text("SCORE")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    Text("\(score)")
                        .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white)
                }

                Text("Level \(level) · \(theme.name)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))

                if stars > 0 {
                    ShareCardButton(card: .level(score: score, stars: stars, level: level, theme: theme, mode: mode)) {
                        Label("Share Result", systemImage: "square.and.arrow.up")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.12))
                            .foregroundStyle(.white.opacity(0.9))
                            .clipShape(Capsule())
                    }
                }

                VStack(spacing: 12) {
                    if hasNextLevel {
                        Button(action: onNext) {
                            Label("Next Level", systemImage: "arrow.right.circle.fill")
                                .font(.system(.headline, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(theme.gradient)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }

                    HStack(spacing: 12) {
                        Button(action: onReplay) {
                            Label("Replay", systemImage: "arrow.counterclockwise")
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(0.15))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        Button(action: onHome) {
                            Label("Home", systemImage: "house.fill")
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(0.15))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
                .padding(.top, 8)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
            // The card's text is white, so keep its material dark even in light mode.
            .environment(\.colorScheme, .dark)
            .padding(24)
        }
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.9)))
    }
}
