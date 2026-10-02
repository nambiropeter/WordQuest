import SwiftUI

@main
struct WordQuestApp: App {
    @StateObject private var progress = ProgressStore.shared
    @StateObject private var settings = SettingsStore.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(progress)
                .environmentObject(settings)
                .preferredColorScheme(settings.appearance.colorScheme)
        }
    }
}
