import SwiftUI
import AppTrackingTransparency

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var tracking: TrackingManager

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
                .onChange(of: settings.showSuggestions) { _, isOn in
                    if isOn {
                        AdsManager.shared.start()
                        AdsManager.shared.loadAd(personalized: tracking.isAuthorized)
                    }
                }

                Toggle(isOn: personalizedBinding) {
                    Label("Personalized Suggestions", systemImage: "person.crop.circle.badge.checkmark")
                }
                .disabled(!settings.showSuggestions)

                if tracking.status == .denied || tracking.status == .restricted {
                    Label {
                        Text("Tracking is off for WordQuest in iOS Settings → Privacy & Security → Tracking.")
                    } icon: {
                        Image(systemName: "hand.raised.slash")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } header: {
                Text("Ads & Personalization")
            } footer: {
                Text("Suggestions are chosen from what you already play, right on your device — nothing is sent anywhere. If personalization is on, iOS will ask your permission before any ad is tailored using tracking, and you can change your mind here anytime.")
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

            #if DEBUG
            Section("Debug") {
                Button("Reset All Progress", role: .destructive) {
                    progress.resetAll()
                }
            }
            #endif

            Section("About") {
                LabeledContent("Version", value: "1.0.0")
                Text("WordQuest features 1,000 Word Search levels and 1,000 Trivia levels across 8 themes: Animals, Geography, Movies & TV, Science, Sports, Food & Cooking, History, and Music.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { tracking.refreshStatus() }
    }

    private var personalizedBinding: Binding<Bool> {
        Binding(
            get: { settings.personalizedAdsEnabled && tracking.isAuthorized },
            set: { newValue in
                if newValue {
                    settings.personalizedAdsEnabled = true
                    tracking.requestIfNeeded()
                } else {
                    settings.personalizedAdsEnabled = false
                }
            }
        )
    }

    private var iCloudStatusFooter: some View {
        HStack(spacing: 6) {
            Image(systemName: progress.iCloudAvailable ? "icloud.fill" : "icloud.slash")
                .foregroundStyle(progress.iCloudAvailable ? .blue : .secondary)
            Text(progress.iCloudAvailable
                 ? "Synced with your Apple ID — progress carries over to your other devices automatically."
                 : "Sign in to iCloud in Settings to sync your progress across devices.")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}
