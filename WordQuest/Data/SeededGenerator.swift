import Foundation

/// Deterministic RNG (SplitMix64) so the same level index always
/// produces the same puzzle/question set across app launches and devices.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: Int) {
        self.state = UInt64(bitPattern: Int64(seed)) &+ 0x9E3779B97F4A7C15
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
