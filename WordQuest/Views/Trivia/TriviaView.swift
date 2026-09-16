import SwiftUI

struct TriviaView: View {
    @StateObject private var vm: TriviaViewModel
    @EnvironmentObject private var router: Router
    private let level: Int
    private let theme: GameTheme

    init(theme: GameTheme, level: Int) {
        self.theme = theme
        self.level = level
        _vm = StateObject(wrappedValue: TriviaViewModel(theme: theme, level: level))
    }

    var body: some View {
        ZStack {
            theme.gradient.opacity(0.12).ignoresSafeArea()

            VStack(spacing: 18) {
                topBar
                timerBar
                progressDots
                questionCard
                Spacer()
                if vm.answerState != .unanswered {
                    nextButton
                }
            }
            .padding()

            if vm.isComplete {
                ResultOverlay(
                    stars: vm.computeStars(),
                    score: vm.score,
                    theme: theme,
                    level: level,
                    mode: .trivia,
                    onReplay: { router.replaceTop(with: .triviaGame(theme, level)) },
                    onNext: { router.replaceTop(with: .triviaGame(theme, level + 1)) },
                    onHome: { router.popToRoot() }
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text("Level \(level)").font(.system(.headline, design: .rounded, weight: .bold))
                    Text(theme.name).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .onAppear { vm.startQuestionTimer() }
        .onDisappear {
            vm.stopTimer()
            if !vm.isComplete { vm.cancelLiveActivity() }
        }
    }

    private var topBar: some View {
        HStack {
            Label("\(vm.score)", systemImage: "star.circle.fill")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(theme.primaryColor)

            if vm.streak > 1 {
                Label("\(vm.streak)", systemImage: "flame.fill")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.orange)
                    .symbolEffect(.bounce, value: vm.streak)
                    .transition(.scale)
                    .accessibilityLabel("\(vm.streak) question streak")
            }

            Spacer()

            Button {
                vm.useFiftyFifty()
            } label: {
                Text("50:50")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(vm.fiftyFiftyUsed ? Color.gray.opacity(0.2) : theme.primaryColor.opacity(0.2))
                    .foregroundStyle(vm.fiftyFiftyUsed ? .secondary : theme.primaryColor)
                    .clipShape(Capsule())
            }
            .disabled(vm.fiftyFiftyUsed || vm.answerState != .unanswered)
            .accessibilityLabel("Fifty-fifty lifeline")
            .accessibilityHint(vm.fiftyFiftyUsed ? "Already used this round" : "Removes two wrong answers")
        }
        .animation(.spring(response: 0.3), value: vm.streak)
    }

    private var timerBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.gray.opacity(0.15))
                Capsule()
                    .fill(vm.timeRemaining <= 3 ? Color.red : theme.primaryColor)
                    .frame(width: geo.size.width * CGFloat(vm.timeRemaining) / CGFloat(max(vm.triviaLevel.timePerQuestion, 1)))
                    .animation(.linear(duration: 1), value: vm.timeRemaining)
            }
        }
        .frame(height: 8)
        .clipShape(Capsule())
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<vm.totalQuestions, id: \.self) { i in
                Circle()
                    .fill(i < vm.currentIndex ? theme.primaryColor : (i == vm.currentIndex ? theme.secondaryColor : Color.gray.opacity(0.2)))
                    .frame(width: 8, height: 8)
            }
        }
    }

    private var questionCard: some View {
        VStack(spacing: 20) {
            Text("Question \(vm.currentIndex + 1) of \(vm.totalQuestions)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(vm.currentQuestion.text)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
                .id(vm.currentIndex)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))

            VStack(spacing: 12) {
                ForEach(Array(vm.currentQuestion.options.enumerated()), id: \.offset) { index, option in
                    optionButton(index: index, option: option)
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .animation(.easeInOut(duration: 0.25), value: vm.currentIndex)
    }

    private func optionButton(index: Int, option: String) -> some View {
        let isEliminated = vm.eliminatedOptions.contains(index)
        let isSelected = vm.selectedIndex == index
        let isCorrectAnswer = index == vm.currentQuestion.correctIndex

        var background: Color {
            guard vm.answerState != .unanswered else {
                return Color(.tertiarySystemGroupedBackground)
            }
            if isCorrectAnswer { return .green.opacity(0.25) }
            if isSelected { return .red.opacity(0.25) }
            return Color(.tertiarySystemGroupedBackground)
        }

        var borderColor: Color {
            guard vm.answerState != .unanswered else { return .clear }
            if isCorrectAnswer { return .green }
            if isSelected { return .red }
            return .clear
        }

        return Button {
            vm.selectAnswer(index)
        } label: {
            HStack {
                Text(option)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .multilineTextAlignment(.leading)
                Spacer()
                if vm.answerState != .unanswered && isCorrectAnswer {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .symbolEffect(.bounce, value: vm.answerState)
                } else if vm.answerState != .unanswered && isSelected {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .symbolEffect(.bounce, value: vm.answerState)
                }
            }
            .padding()
            .background(background)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(borderColor, lineWidth: 2))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .opacity(isEliminated ? 0.25 : 1)
        .disabled(vm.answerState != .unanswered || isEliminated)
        .animation(.easeInOut(duration: 0.2), value: vm.answerState)
    }

    private var nextButton: some View {
        Button {
            vm.advance()
        } label: {
            Text(vm.isLastQuestion ? "Finish" : "Next Question")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding()
                .background(theme.gradient)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
