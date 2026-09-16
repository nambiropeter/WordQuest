import SwiftUI

/// The single "suggested for you" slot on Home. Shows a real native ad once
/// one has loaded; otherwise falls back to first-party house content, so
/// the slot always looks intentional rather than sitting empty or popping
/// in abruptly.
struct GentleAdCard: View {
    @ObservedObject var ads: AdsManager
    let houseAd: HouseAd
    let onHouseAdTap: () -> Void

    var body: some View {
        Group {
            if let nativeAd = ads.nativeAd {
                NativeAdContainerView(nativeAd: nativeAd, tintColor: houseAd.tintColor)
                    .frame(minHeight: 84)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            } else {
                houseAdButton
            }
        }
        .padding(.horizontal)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: ads.nativeAd != nil)
    }

    private var houseAdButton: some View {
        Button(action: onHouseAdTap) {
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
        .accessibilityLabel("Suggested: \(houseAd.title)")
        .accessibilityHint(houseAd.subtitle)
    }
}
