import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var settings: SettingsStore
    @ObservedObject private var ads = AdsManager.shared
    @State private var quickPlayTheme: GameTheme?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header

                VStack(spacing: 16) {
                    modeCard(
                        mode: .wordSearch,
                        subtitle: "Find hidden words in a themed grid",
                        gradient: LinearGradient(colors: [Color(hex: "#2A9D8F"), Color(hex: "#264653")], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    modeCard(
                        mode: .trivia,
                        subtitle: "Test your knowledge, beat the clock",
                        gradient: LinearGradient(colors: [Color(hex: "#EF476F"), Color(hex: "#7209B7")], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    multiplayerCard
                }
                .padding(.horizontal)

                themeStrip

                if settings.showSuggestions {
                    GentleAdCard(ads: ads, houseAd: houseAd) {
                        Haptics.light()
                        switch houseAd.action {
                        case .openMultiplayer:
                            router.push(.multiplayer(nil))
                        case .openTheme(let theme):
                            quickPlayTheme = theme
                        }
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(.top, 8)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("WordQuest")
                    .font(.system(.headline, design: .rounded, weight: .bold))
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: AppRoute.settings) {
                    Image(systemName: "gearshape.fill")
                }
            }
        }
        .sheet(item: $quickPlayTheme) { theme in
            ThemeQuickPlaySheet(theme: theme) { choice in
                quickPlayTheme = nil
                switch choice {
                case .solo(let mode):
                    router.push(.levelMap(mode, theme))
                case .multiplayerTrivia:
                    router.push(.multiplayer(theme))
                }
            }
            .presentationDetents([.medium])
        }
    }

    private var houseAd: HouseAd {
        HouseAdProvider.recommendation(progress: progress)
    }

    private var header: some View {
        HStack(spacing: 16) {
            statChip(icon: "star.fill", tint: .yellow, value: "\(progress.totalStars)")
            statChip(icon: "circle.hexagongrid.fill", tint: .orange, value: "\(progress.totalCoins)")
            statChip(icon: "checkmark.seal.fill", tint: .green, value: "\(progress.levelsCompleted)")
        }
        .padding(.horizontal)
    }

    private func statChip(icon: String, tint: Color, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(value).font(.system(.subheadline, design: .rounded, weight: .bold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(Capsule())
    }

    private func modeCard(mode: GameMode, subtitle: String, gradient: LinearGradient) -> some View {
        NavigationLink(value: AppRoute.themeSelect(mode)) {
            HStack(spacing: 16) {
                Image(systemName: mode.icon)
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.displayName)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.85))
                    Text("8 themes · 1,000 levels each")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(20)
            .background(gradient)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.15), radius: 10, y: 6)
        }
        .buttonStyle(.plain)
    }

    private var multiplayerCard: some View {
        NavigationLink(value: AppRoute.multiplayer(nil)) {
            HStack(spacing: 16) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Local Multiplayer")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Live trivia with up to 8 nearby friends — no internet needed")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(20)
            .background(LinearGradient(colors: [Color(hex: "#118AB2"), Color(hex: "#073B4C")], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.15), radius: 10, y: 6)
        }
        .buttonStyle(.plain)
    }

    private var themeStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Jump Into a Theme")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                Text("Tap one to play solo or with friends nearby")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(ContentStore.shared.themes) { theme in
                        Button {
                            Haptics.light()
                            quickPlayTheme = theme
                        } label: {
                            ZStack(alignment: .topLeading) {
                                theme.gradient

                                Circle()
                                    .fill(.white.opacity(0.16))
                                    .frame(width: 90, height: 90)
                                    .offset(x: 60, y: -40)

                                VStack(alignment: .leading, spacing: 0) {
                                    Image(systemName: theme.icon)
                                        .font(.system(size: 26))
                                        .foregroundStyle(.white)
                                        .frame(width: 46, height: 46)
                                        .background(.white.opacity(0.22))
                                        .clipShape(Circle())

                                    Spacer(minLength: 14)

                                    Text(theme.name)
                                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.85)

                                    HStack(spacing: 3) {
                                        Text("Play")
                                            .font(.caption2.weight(.bold))
                                        Image(systemName: "arrow.right")
                                            .font(.caption2.weight(.bold))
                                    }
                                    .foregroundStyle(.white.opacity(0.85))
                                }
                                .padding(14)
                            }
                            .frame(width: 128, height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 22))
                            .shadow(color: theme.primaryColor.opacity(0.35), radius: 8, y: 5)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                router.push(.levelMap(.wordSearch, theme))
                            } label: {
                                Label("Play Word Search", systemImage: "square.grid.3x3.fill")
                            }
                            Button {
                                router.push(.levelMap(.trivia, theme))
                            } label: {
                                Label("Play Trivia", systemImage: "questionmark.circle.fill")
                            }
                            Button {
                                router.push(.multiplayer(theme))
                            } label: {
                                Label("Host Multiplayer Trivia", systemImage: "antenna.radiowaves.left.and.right")
                            }
                        }
                        .accessibilityLabel("\(theme.name) theme")
                        .accessibilityHint("Double tap to choose solo or multiplayer, then a game")
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
        }
    }
}
