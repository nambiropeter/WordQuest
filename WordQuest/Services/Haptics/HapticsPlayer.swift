import CoreHaptics

/// A custom CoreHaptics pattern for the "level complete" moment, layered on
/// top of the basic UIFeedbackGenerator taps already used elsewhere. Every
/// entry point here fails silently: the Simulator and older devices have no
/// Taptic Engine, so `supportsHaptics` is false there and this becomes a
/// no-op rather than a crash.
final class HapticsPlayer {
    static let shared = HapticsPlayer()

    private var engine: CHHapticEngine?

    private init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            engine.resetHandler = { [weak engine] in try? engine?.start() }
            engine.stoppedHandler = { _ in }
            try engine.start()
            self.engine = engine
        } catch {
            engine = nil
        }
    }

    /// A short rising four-tap flourish for finishing a level.
    func playLevelComplete() {
        guard engine != nil else { return }
        let times: [TimeInterval] = [0, 0.09, 0.18, 0.30]
        let intensities: [Float] = [0.55, 0.7, 0.85, 1.0]
        let sharpnesses: [Float] = [0.3, 0.4, 0.55, 0.75]

        let events = zip(times, zip(intensities, sharpnesses)).map { time, pair -> CHHapticEvent in
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: pair.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: pair.1)
                ],
                relativeTime: time
            )
        }

        play(events)
    }

    /// A single sharp pulse for a correct trivia answer.
    func playCorrectPulse() {
        guard engine != nil else { return }
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
            ],
            relativeTime: 0
        )
        play([event])
    }

    private func play(_ events: [CHHapticEvent]) {
        guard let engine else { return }
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            // Basic UIFeedbackGenerator calls elsewhere already cover the minimum.
        }
    }
}
