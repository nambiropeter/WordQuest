import SwiftUI

struct ThemeSelectView: View {
    let mode: GameMode
    @EnvironmentObject private var progress: ProgressStore

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(ContentStore.shared.themes) { theme in
                    NavigationLink(value: AppRoute.levelMap(mode, theme)) {
                        themeCard(theme)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Choose a Theme")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func themeCard(_ theme: GameTheme) -> some View {
        let completed = progress.themeLevelsCompleted(mode: mode, theme: theme)
        let stars = progress.themeStars(mode: mode, theme: theme)

        return VStack(spacing: 10) {
            Image(systemName: theme.icon)
                .font(.system(size: 30))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(theme.gradient)
                .clipShape(Circle())

            Text(theme.name)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)

            if completed > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow)
                    Text("\(stars) · \(completed)/\(GameMode.levelCount)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Start playing")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
