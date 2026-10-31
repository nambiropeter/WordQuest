import SwiftUI

/// The single "suggested for you" slot on Home. First-party only — the app
/// recommending an unexplored theme or local multiplayer, chosen entirely
/// on-device from what the player has (and hasn't) already played. No
/// third-party ad network is involved, so there is nothing to label "Ad".
struct SuggestedCard: View {
    let houseAd: HouseAd
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: houseAd.icon)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(houseAd.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text(houseAd.title)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(houseAd.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(alignment: .topTrailing) {
                Text("Suggested")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.thinMaterial, in: Capsule())
                    .padding(8)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .accessibilityLabel("Suggested: \(houseAd.title)")
        .accessibilityHint(houseAd.subtitle)
    }
}
