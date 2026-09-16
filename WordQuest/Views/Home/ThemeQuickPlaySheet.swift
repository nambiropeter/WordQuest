import SwiftUI

enum QuickPlayChoice {
    case solo(GameMode)
    case multiplayerTrivia
}

struct ThemeQuickPlaySheet: View {
    let theme: GameTheme
    let onConfirm: (QuickPlayChoice) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var step: Step = .playerCount
    @State private var wantsMultiplayer = false

    private enum Step { case playerCount, game }

    var body: some View {
        VStack(spacing: 24) {
            header

            switch step {
            case .playerCount:
                playerCountStep
            case .game:
                gameStep
            }

            Spacer()
        }
        .padding(.top, 8)
        .padding(.horizontal)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private var header: some View {
        HStack(spacing: 12) {
            if step == .game {
                Button {
                    withAnimation { step = .playerCount }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }

            Image(systemName: theme.icon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(theme.gradient)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(theme.name)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                Text(step == .playerCount ? "How do you want to play?" : "Choose a game")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.top, 12)
    }

    private var playerCountStep: some View {
        VStack(spacing: 14) {
            choiceButton(
                icon: "person.fill",
                title: "Solo",
                subtitle: "Play at your own pace",
                gradient: theme.gradient
            ) {
                wantsMultiplayer = false
                withAnimation { step = .game }
            }

            choiceButton(
                icon: "person.2.fill",
                title: "With Others",
                subtitle: "Live trivia with nearby friends",
                gradient: LinearGradient(colors: [Color(hex: "#118AB2"), Color(hex: "#073B4C")], startPoint: .leading, endPoint: .trailing)
            ) {
                wantsMultiplayer = true
                withAnimation { step = .game }
            }
        }
    }

    private var gameStep: some View {
        VStack(spacing: 14) {
            choiceButton(
                icon: "square.grid.3x3.fill",
                title: "Word Search",
                subtitle: wantsMultiplayer ? "Multiplayer coming soon" : "Find hidden words in the grid",
                gradient: LinearGradient(colors: [Color(hex: "#2A9D8F"), Color(hex: "#264653")], startPoint: .leading, endPoint: .trailing),
                disabled: wantsMultiplayer
            ) {
                onConfirm(.solo(.wordSearch))
            }

            choiceButton(
                icon: "questionmark.circle.fill",
                title: "Trivia",
                subtitle: wantsMultiplayer ? "Host or join nearby players" : "Test your knowledge, beat the clock",
                gradient: LinearGradient(colors: [Color(hex: "#EF476F"), Color(hex: "#7209B7")], startPoint: .leading, endPoint: .trailing)
            ) {
                onConfirm(wantsMultiplayer ? .multiplayerTrivia : .solo(.trivia))
            }
        }
    }

    private func choiceButton(
        icon: String,
        title: String,
        subtitle: String,
        gradient: LinearGradient,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(disabled ? AnyShapeStyle(Color.gray.opacity(0.4)) : AnyShapeStyle(gradient))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(.headline, design: .rounded, weight: .bold))
                        if disabled {
                            Text("SOON")
                                .font(.system(size: 9, weight: .heavy))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.25))
                                .clipShape(Capsule())
                        }
                    }
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !disabled {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.6 : 1)
    }
}
