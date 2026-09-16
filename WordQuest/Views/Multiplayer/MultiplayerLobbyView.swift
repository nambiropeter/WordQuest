import SwiftUI
import MultipeerConnectivity

struct MultiplayerLobbyView: View {
    let initialTheme: GameTheme?
    @StateObject private var vm = MultiplayerViewModel()
    @EnvironmentObject private var router: Router
    @State private var appliedInitialTheme = false

    init(initialTheme: GameTheme? = nil) {
        self.initialTheme = initialTheme
    }

    var body: some View {
        Group {
            switch vm.phase {
            case .roleSelect:
                roleSelectContent
            case .browsing:
                browsingContent
            case .lobby:
                MultiplayerRoomView(vm: vm)
            case .playing:
                MultiplayerGameView(vm: vm)
            case .results:
                MultiplayerResultsView(vm: vm, onLeave: leaveAndPop)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Local Multiplayer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if vm.phase != .roleSelect {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Leave", role: .destructive, action: leaveAndPop)
                }
            }
        }
        .onDisappear {
            if vm.phase != .roleSelect {
                vm.leaveGame()
            }
        }
        .onAppear {
            guard !appliedInitialTheme, let initialTheme else { return }
            appliedInitialTheme = true
            vm.selectedTheme = initialTheme
        }
    }

    private func leaveAndPop() {
        vm.leaveGame()
        router.path.removeLast()
    }

    private var roleSelectContent: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 46))
                        .foregroundStyle(LinearGradient(colors: [Color(hex: "#118AB2"), Color(hex: "#073B4C")], startPoint: .top, endPoint: .bottom))
                    Text("Play trivia with friends nearby")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .multilineTextAlignment(.center)
                    Text("No internet needed — connects over Bluetooth or your local Wi-Fi network automatically. Up to \(MultiplayerViewModel.maxPlayers) players per game.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 24)

                VStack(alignment: .leading, spacing: 8) {
                    Text("YOUR NAME")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    TextField("Player name", text: $vm.playerName)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: vm.playerName) { _, newValue in
                            vm.updatePlayerName(newValue)
                        }
                }
                .padding(.horizontal)

                VStack(spacing: 14) {
                    Button {
                        vm.startHosting()
                    } label: {
                        Label("Host a Game", systemImage: "personalhotspot")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(LinearGradient(colors: [Color(hex: "#118AB2"), Color(hex: "#073B4C")], startPoint: .leading, endPoint: .trailing))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    Button {
                        vm.startBrowsing()
                    } label: {
                        Label("Join a Game", systemImage: "magnifyingglass")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var browsingContent: some View {
        VStack(spacing: 20) {
            ProgressView()
                .padding(.top, 32)
            Text("Searching for nearby games…")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)

            if vm.discoveredHosts.isEmpty {
                Spacer()
                Text("Make sure a friend has tapped \"Host a Game\" nearby.\nBluetooth and Local Network access must be allowed.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
            } else {
                List(vm.discoveredHosts, id: \.self) { peer in
                    Button {
                        vm.joinHost(peer)
                    } label: {
                        HStack {
                            Image(systemName: "personalhotspot")
                                .foregroundStyle(.blue)
                            Text(displayName(for: peer))
                                .font(.system(.body, design: .rounded, weight: .semibold))
                            Spacer()
                            if vm.connectingToHost == peer {
                                ProgressView()
                            } else {
                                Image(systemName: "chevron.right").foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    private func displayName(for peer: MCPeerID) -> String {
        String(peer.displayName.split(separator: "#").first ?? Substring(peer.displayName))
    }
}
