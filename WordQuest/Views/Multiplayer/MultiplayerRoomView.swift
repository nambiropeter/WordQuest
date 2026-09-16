import SwiftUI

struct MultiplayerRoomView: View {
    @ObservedObject var vm: MultiplayerViewModel

    private let questionCountOptions = [5, 8, 12]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if vm.isHost {
                    hostControls
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Waiting for the host to start the game…")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 24)
                }

                playerList
            }
            .padding(.vertical, 16)
        }
    }

    private var hostControls: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("THEME")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        themeChip(theme: nil, label: "Mixed", icon: "sparkles")
                        ForEach(ContentStore.shared.themes) { theme in
                            themeChip(theme: theme, label: theme.name, icon: theme.icon)
                        }
                    }
                    .padding(.horizontal)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("QUESTIONS")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                Picker("Question Count", selection: $vm.questionCount) {
                    ForEach(questionCountOptions, id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
            }

            Button {
                vm.startGame()
            } label: {
                Label("Start Game", systemImage: "play.fill")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LinearGradient(colors: [Color(hex: "#118AB2"), Color(hex: "#073B4C")], startPoint: .leading, endPoint: .trailing))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
        }
    }

    private func themeChip(theme: GameTheme?, label: String, icon: String) -> some View {
        let isSelected = vm.selectedTheme?.id == theme?.id
        return Button {
            vm.selectedTheme = theme
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
            }
            .frame(width: 68, height: 64)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(isSelected ? AnyShapeStyle(theme?.gradient ?? LinearGradient(colors: [Color(hex: "#7209B7"), Color(hex: "#EF476F")], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Color(.secondarySystemGroupedBackground)))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var playerList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PLAYERS (\(vm.players.count)/\(MultiplayerViewModel.maxPlayers))")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            if vm.isHost && vm.players.count >= MultiplayerViewModel.maxPlayers {
                Text("Session is full — this game supports up to \(MultiplayerViewModel.maxPlayers) players.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal)
            }

            VStack(spacing: 0) {
                ForEach(Array(vm.players.enumerated()), id: \.element.id) { index, player in
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundStyle(.blue)
                        Text(player.name)
                            .font(.system(.body, design: .rounded, weight: .semibold))
                        if player.id == vm.myID {
                            Text("(You)").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    if index < vm.players.count - 1 {
                        Divider().padding(.leading, 44)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
    }
}
