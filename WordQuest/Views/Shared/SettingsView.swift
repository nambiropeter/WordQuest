import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var progress: ProgressStore
    @ObservedObject private var gameCenter = GameCenterManager.shared
    @State private var showResetConfirmation = false

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $settings.appearance) {
                    ForEach(AppAppearance.allCases, id: \.self) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Preferences") {
                Toggle(isOn: $settings.soundEnabled) {
                    Label("Sound Effects", systemImage: "speaker.wave.2.fill")
                }
                Toggle(isOn: $settings.hapticsEnabled) {
                    Label("Haptic Feedback", systemImage: "hand.tap.fill")
                }
            }

            Section {
                Toggle(isOn: $settings.showSuggestions) {
                    Label("Suggested For You", systemImage: "sparkles")
                }
            } header: {
                Text("Suggestions")
            } footer: {
                Text("Chosen from what you already play, right on your device — nothing is sent anywhere.")
            }

            Section {
                LabeledContent("Total Stars", value: "\(progress.totalStars)")
                LabeledContent("Coins", value: "\(progress.totalCoins)")
                LabeledContent("Levels Completed", value: "\(progress.levelsCompleted)")
            } header: {
                Text("Progress")
            } footer: {
                iCloudStatusFooter
            }

            Section {
                Button { gameCenter.open(.leaderboards) } label: {
                    Label("Leaderboards", systemImage: "list.number")
                }
                Button { gameCenter.open(.achievements) } label: {
                    Label("Achievements", systemImage: "trophy.fill")
                }
                Button { gameCenter.open(.profile) } label: {
                    Label("Game Center Profile", systemImage: "person.crop.circle")
                }
            } header: {
                Text("Game Center")
            } footer: {
                if !gameCenter.isAuthenticated {
                    Text("Sign in to Game Center in the Settings app to see leaderboards and achievements.")
                }
            }
            .disabled(!gameCenter.isAuthenticated)

            #if DEBUG
            Section("Debug") {
                Button("Reset All Progress", role: .destructive) {
                    showResetConfirmation = true
                }
            }
            #endif

            Section("About") {
                LabeledContent("Version", value: Self.appVersion)
                Text("WordQuest features 1,000 Word Search levels and 1,000 Trivia levels across 8 themes: Animals, Geography, Movies & TV, Science, Sports, Food & Cooking, History, and Music.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Reset all progress?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            #if DEBUG
            Button("Reset", role: .destructive) { progress.resetAll() }
            #endif
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes every level's stars, scores, and coins. This can't be undone.")
        }
    }

    /// Read from the bundle rather than hardcoded, so a version bump in the
    /// project settings is the single place it has to change.
    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var iCloudStatusFooter: some View {
        HStack(spacing: 6) {
            Image(systemName: progress.iCloudAvailable ? "icloud.fill" : "iphone")
                .foregroundStyle(progress.iCloudAvailable ? .blue : .secondary)
            Text(statusText)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private var statusText: String {
        if progress.iCloudAvailable {
            return "Synced with your Apple ID — progress carries over to your other devices automatically."
        }
        // Don't tell the player to sign into iCloud when this build can't use
        // it at all; that would be advice that changes nothing.
        if ProgressStore.isCloudSyncEnabled {
            return "Sign in to iCloud in Settings to sync your progress across devices."
        }
        return "Progress is saved on this device."
    }
}
