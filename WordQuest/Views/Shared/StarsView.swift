import SwiftUI

struct StarsView: View {
    let filled: Int
    let total: Int = 3
    var size: CGFloat = 16

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<total, id: \.self) { i in
                Image(systemName: i < filled ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(i < filled ? .yellow : .gray.opacity(0.4))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(filled) out of \(total) stars")
    }
}

struct AnimatedStarsView: View {
    let filled: Int
    var size: CGFloat = 40
    @State private var appeared: [Bool] = [false, false, false]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: i < filled ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(i < filled ? .yellow : .gray.opacity(0.3))
                    .scaleEffect(appeared[i] ? 1 : (reduceMotion ? 1 : 0.1))
                    .rotationEffect(.degrees(appeared[i] || reduceMotion ? 0 : -45))
                    .symbolEffect(.bounce, value: appeared[i])
                    .onAppear {
                        if reduceMotion {
                            appeared[i] = true
                        } else {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.55).delay(Double(i) * 0.15)) {
                                appeared[i] = true
                            }
                        }
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(filled) out of 3 stars")
    }
}
