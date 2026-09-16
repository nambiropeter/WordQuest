import SwiftUI

struct MultiplayerResultsView: View {
    @ObservedObject var vm: MultiplayerViewModel
    let onLeave: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 46))
                        .foregroundStyle(.yellow)
                        .symbolEffect(.bounce, value: vm.scores.count)
                    Text("Game Over")
                        .font(.system(.title, design: .rounded, weight: .heavy))
                    if let rank = vm.myRank {
                        Text("You finished #\(rank) of \(vm.scores.count)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let myScore = vm.myScore {
                        ShareLink(item: shareText(myScore)) {
                            Label("Share Result", systemImage: "square.and.arrow.up")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.purple.opacity(0.12))
                                .foregroundStyle(.purple)
                                .clipShape(Capsule())
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.top, 24)

                VStack(spacing: 0) {
                    ForEach(Array(vm.scores.enumerated()), id: \.element.id) { index, entry in
                        HStack(spacing: 12) {
                            rankBadge(index + 1)
                            Text(entry.name)
                                .font(.system(.body, design: .rounded, weight: .semibold))
                            if entry.id == vm.myID {
                                Text("(You)").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(entry.score)")
                                .font(.system(.body, design: .rounded, weight: .heavy))
                        }
                        .padding()
                        .background(entry.id == vm.myID ? Color.purple.opacity(0.08) : Color.clear)

                        if index < vm.scores.count - 1 {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal)

                VStack(spacing: 12) {
                    if vm.isHost {
                        Button {
                            vm.startGame()
                        } label: {
                            Label("Play Again", systemImage: "arrow.counterclockwise")
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(LinearGradient(colors: [Color(hex: "#118AB2"), Color(hex: "#073B4C")], startPoint: .leading, endPoint: .trailing))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    } else {
                        Text("Waiting for the host to start a new round…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Button(role: .destructive, action: onLeave) {
                        Label("Leave", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
    }

    private func shareText(_ score: PlayerScore) -> String {
        let rank = vm.myRank ?? 1
        return "I just finished #\(rank) of \(vm.scores.count) with \(score.score) points in a WordQuest local multiplayer trivia game! 🏆"
    }

    private func rankBadge(_ rank: Int) -> some View {
        let symbol: String
        let color: Color
        switch rank {
        case 1: symbol = "1.circle.fill"; color = .yellow
        case 2: symbol = "2.circle.fill"; color = .gray
        case 3: symbol = "3.circle.fill"; color = .brown
        default: symbol = "\(rank).circle.fill"; color = .secondary
        }
        return Image(systemName: symbol)
            .font(.title3)
            .foregroundStyle(color)
    }
}
