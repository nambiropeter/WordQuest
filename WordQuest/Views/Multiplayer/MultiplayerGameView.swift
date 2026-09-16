import SwiftUI

struct MultiplayerGameView: View {
    @ObservedObject var vm: MultiplayerViewModel

    private var theme: GameTheme {
        vm.themeForGame ?? GameTheme(id: "mixed", name: "Mixed", icon: "sparkles", colorPrimary: "#7209B7", colorSecondary: "#EF476F")
    }

    var body: some View {
        ZStack {
            theme.gradient.opacity(0.12).ignoresSafeArea()

            VStack(spacing: 16) {
                leaderboardStrip
                timerBar
                progressLabel

                if let question = vm.currentQuestion {
                    questionCard(question)
                } else {
                    ProgressView()
                }

                if vm.hasAnswered && vm.revealedCorrectIndex == nil {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Waiting for other players…")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding()
        }
    }

    private var leaderboardStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(topScores, id: \.id) { entry in
                    HStack(spacing: 6) {
                        Text(entry.name)
                            .font(.caption.weight(.bold))
                            .lineLimit(1)
                        Text("\(entry.score)")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(theme.primaryColor)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(entry.id == vm.myID ? theme.primaryColor.opacity(0.18) : Color(.secondarySystemGroupedBackground))
                    .clipShape(Capsule())
                }
            }
        }
    }

    private var topScores: [PlayerScore] {
        if vm.scores.isEmpty {
            return vm.players.map { PlayerScore(id: $0.id, name: $0.name, score: 0, correctCount: 0) }
        }
        return vm.scores
    }

    private var timerBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.gray.opacity(0.15))
                Capsule()
                    .fill(vm.timeRemaining <= 3 ? Color.red : theme.primaryColor)
                    .frame(width: geo.size.width * CGFloat(vm.timeRemaining) / CGFloat(max(vm.timePerQuestion, 1)))
                    .animation(.linear(duration: 1), value: vm.timeRemaining)
            }
        }
        .frame(height: 8)
        .clipShape(Capsule())
    }

    private var progressLabel: some View {
        Text("Question \(vm.currentIndex + 1) of \(vm.totalQuestions) · \(theme.name)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func questionCard(_ question: NetworkQuestion) -> some View {
        VStack(spacing: 20) {
            Text(question.text)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)

            VStack(spacing: 12) {
                ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                    optionButton(index: index, option: option)
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func optionButton(index: Int, option: String) -> some View {
        let isSelected = vm.selectedAnswer == index
        let revealed = vm.revealedCorrectIndex != nil
        let isCorrectAnswer = revealed && index == vm.revealedCorrectIndex

        var background: Color {
            guard revealed else {
                return isSelected ? theme.primaryColor.opacity(0.2) : Color(.tertiarySystemGroupedBackground)
            }
            if isCorrectAnswer { return .green.opacity(0.25) }
            if isSelected { return .red.opacity(0.25) }
            return Color(.tertiarySystemGroupedBackground)
        }

        return Button {
            vm.selectAnswer(index)
        } label: {
            HStack {
                Text(option)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .multilineTextAlignment(.leading)
                Spacer()
                if revealed && isCorrectAnswer {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                } else if revealed && isSelected {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                }
            }
            .padding()
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(vm.hasAnswered)
        .animation(.easeInOut(duration: 0.2), value: vm.revealedCorrectIndex)
    }
}
