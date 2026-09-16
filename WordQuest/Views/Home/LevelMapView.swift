import SwiftUI

struct LevelMapView: View {
    let mode: GameMode
    let theme: GameTheme
    @EnvironmentObject private var progress: ProgressStore

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)
    private let bandSize = GameMode.tierSize

    private var bandCount: Int { GameMode.tierCount }
    private var resumeLevel: Int { progress.furthestReachedLevel(for: mode, theme: theme) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                header
                tierJumpBar(proxy: proxy)

                LazyVStack(spacing: 24, pinnedViews: [.sectionHeaders]) {
                    ForEach(0..<bandCount, id: \.self) { band in
                        let startLevel = band * bandSize + 1
                        let endLevel = min(startLevel + bandSize - 1, GameMode.levelCount)

                        Section {
                            LazyVGrid(columns: columns, spacing: 14) {
                                ForEach(startLevel...endLevel, id: \.self) { level in
                                    LevelButton(
                                        level: level,
                                        mode: mode,
                                        theme: theme,
                                        isUnlocked: progress.isUnlocked(level, mode: mode, theme: theme),
                                        result: progress.result(for: level, mode: mode, theme: theme)
                                    )
                                    .id(level)
                                }
                            }
                            .padding(.horizontal)
                        } header: {
                            HStack {
                                Text("Difficulty Tier \(band + 1)")
                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                                Spacer()
                                Text("\(startLevel)–\(endLevel)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                        }
                        .id("tier-\(band)")
                    }
                }
                .padding(.bottom, 12)
            }
            .onAppear {
                proxy.scrollTo(resumeLevel, anchor: .center)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(theme.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: theme.icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(theme.gradient)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("\(mode.displayName) · \(theme.name)")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                Text("\(progress.themeStars(mode: mode, theme: theme)) stars · \(progress.themeLevelsCompleted(mode: mode, theme: theme))/\(GameMode.levelCount) complete")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
    }

    private func tierJumpBar(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("JUMP TO A DIFFICULTY")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(0..<bandCount, id: \.self) { band in
                        Button {
                            withAnimation {
                                proxy.scrollTo("tier-\(band)", anchor: .top)
                            }
                        } label: {
                            Text("Tier \(band + 1)")
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(theme.primaryColor.opacity(0.15))
                                .foregroundStyle(theme.primaryColor)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom, 4)
    }
}

private struct LevelButton: View {
    let level: Int
    let mode: GameMode
    let theme: GameTheme
    let isUnlocked: Bool
    let result: LevelResult?

    var body: some View {
        Group {
            if isUnlocked {
                NavigationLink(value: mode == .wordSearch ? AppRoute.wordSearchGame(theme, level) : AppRoute.triviaGame(theme, level)) {
                    content
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
    }

    private var content: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? AnyShapeStyle(theme.gradient) : AnyShapeStyle(Color.gray.opacity(0.25)))
                    .frame(width: 48, height: 48)

                if isUnlocked {
                    Text("\(level)")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                }
            }
            if let result {
                StarsView(filled: result.stars, size: 8)
            } else {
                Spacer().frame(height: 10)
            }
        }
        .opacity(isUnlocked ? 1 : 0.5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isUnlocked ? .isButton : [])
    }

    private var accessibilityLabel: String {
        guard isUnlocked else { return "Level \(level), locked" }
        if let result {
            return "Level \(level), \(result.stars) out of 3 stars"
        }
        return "Level \(level), not yet played"
    }
}
