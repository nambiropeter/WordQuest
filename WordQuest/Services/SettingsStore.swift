import SwiftUI
import Combine

enum AppAppearance: String, CaseIterable, Codable {
    case system, light, dark

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var soundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(soundEnabled, forKey: "wq.settings.sound")
            SoundManager.isEnabled = soundEnabled
        }
    }

    @Published var hapticsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(hapticsEnabled, forKey: "wq.settings.haptics")
            Haptics.isEnabled = hapticsEnabled
        }
    }

    @Published var appearance: AppAppearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: "wq.settings.appearance") }
    }

    /// Governs the small "suggested for you" card on Home — off by default
    /// isn't required, but the player can turn it off entirely at any time.
    @Published var showSuggestions: Bool {
        didSet { UserDefaults.standard.set(showSuggestions, forKey: "wq.settings.showSuggestions") }
    }

    /// Whether the player has opted in to tracking-based ad personalization.
    /// This only reflects intent — the actual permission lives in iOS's App
    /// Tracking Transparency system prompt (see TrackingManager) and always
    /// wins over this flag.
    @Published var personalizedAdsEnabled: Bool {
        didSet { UserDefaults.standard.set(personalizedAdsEnabled, forKey: "wq.settings.personalizedAds") }
    }

    private init() {
        let defaults = UserDefaults.standard
        self.soundEnabled = defaults.object(forKey: "wq.settings.sound") as? Bool ?? true
        self.hapticsEnabled = defaults.object(forKey: "wq.settings.haptics") as? Bool ?? true
        self.appearance = AppAppearance(rawValue: defaults.string(forKey: "wq.settings.appearance") ?? "") ?? .system
        self.showSuggestions = defaults.object(forKey: "wq.settings.showSuggestions") as? Bool ?? true
        self.personalizedAdsEnabled = defaults.object(forKey: "wq.settings.personalizedAds") as? Bool ?? false
        SoundManager.isEnabled = soundEnabled
        Haptics.isEnabled = hapticsEnabled
    }
}
