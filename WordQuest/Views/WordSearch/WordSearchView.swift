import SwiftUI

struct WordSearchView: View {
    @StateObject private var vm: WordSearchViewModel
    @EnvironmentObject private var router: Router
    private let level: Int
    private let theme: GameTheme

    init(theme: GameTheme, level: Int) {
        self.theme = theme
        self.level = level
        _vm = StateObject(wrappedValue: WordSearchViewModel(theme: theme, level: level))
    }

    var body: some View {
        ZStack {
            theme.primaryColor.opacity(0.08).ignoresSafeArea()

            VStack(spacing: 16) {
                topBar
                wordBank
                WordSearchGridView(vm: vm)
                    .padding(.horizontal, 12)
                Spacer()
            }
            .padding(.top, 8)

            if vm.isComplete {
                ResultOverlay(
                    stars: vm.computeStars(),
                    score: vm.foundCount * 100,
                    theme: theme,
                    level: level,
                    mode: .wordSearch,
                    onReplay: { router.replaceTop(with: .wordSearchGame(theme, level)) },
                    onNext: { router.replaceTop(with: .wordSearchGame(theme, level + 1)) },
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
        .onAppear { vm.startTimer() }
        .onDisappear { vm.stopTimer() }
    }

    private var topBar: some View {
        HStack {
            Label(timeString(vm.elapsedSeconds), systemImage: "clock.fill")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))

            Spacer()

            Text("\(vm.foundCount)/\(vm.totalWords)")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(theme.gradient)
                .foregroundStyle(.white)
                .clipShape(Capsule())

            Spacer()

            Button {
                vm.useHint()
            } label: {
                Label("\(vm.hintsRemaining)", systemImage: "lightbulb.fill")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
            }
            .disabled(vm.hintsRemaining == 0)
        }
        .padding(.horizontal)
    }

    private var wordBank: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(vm.puzzle.placedWords) { placed in
                    Text(placed.word)
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .strikethrough(placed.isFound)
                        .foregroundStyle(placed.isFound ? .secondary : .primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(placed.isFound ? Color.green.opacity(0.15) : Color(.secondarySystemBackground))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
        }
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
