import AudioToolbox

/// Lightweight system-sound based SFX so the app has audio feedback
/// without bundling binary audio assets. Respects the user's settings toggle.
enum SoundManager {
    static var isEnabled = true

    static func wordFound() {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(1104)
    }

    static func levelComplete() {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(1025)
    }

    static func correctAnswer() {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(1057)
    }

    static func wrongAnswer() {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(1053)
    }

    static func tick() {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(1103)
    }

    static func tap() {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(1104)
    }
}
