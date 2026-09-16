import SwiftUI

@main
struct WordQuestApp: App {
    @StateObject private var progress = ProgressStore.shared
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var tracking = TrackingManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(progress)
                .environmentObject(settings)
                .environmentObject(tracking)
                .preferredColorScheme(settings.appearance.colorScheme)
        }
    }
}
