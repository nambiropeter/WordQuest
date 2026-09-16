import SwiftUI

struct GameTheme: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let colorPrimary: String
    let colorSecondary: String

    var gradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: colorPrimary), Color(hex: colorSecondary)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var primaryColor: Color { Color(hex: colorPrimary) }
    var secondaryColor: Color { Color(hex: colorSecondary) }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
