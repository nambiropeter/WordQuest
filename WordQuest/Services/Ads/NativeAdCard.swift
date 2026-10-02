import GoogleMobileAds
import SwiftUI
import UIKit

/// A native ad drawn as one of the app's own cards — same shape, spacing and
/// colors as Home's `SuggestedCard` — with a clear "Ad" label (required by
/// AdMob policy). Takes no space until an ad has actually loaded.
/// Android counterpart: `ui/components/NativeAdCard.kt`.
struct NativeAdCard: View {
    @ObservedObject private var ads = AdsManager.shared
    @StateObject private var loader = NativeAdLoader()

    var body: some View {
        Group {
            if let ad = loader.ad {
                NativeCardRepresentable(ad: ad)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal)
            } else {
                // Zero-height stand-in so onAppear/onChange below always have a view to fire on.
                Color.clear.frame(height: 0)
            }
        }
        .onAppear { if ads.isReady { loader.load() } }
        .onChange(of: ads.isReady) { _, ready in if ready { loader.load() } }
    }
}

@MainActor
private final class NativeAdLoader: NSObject, ObservableObject, NativeAdLoaderDelegate {
    @Published private(set) var ad: NativeAd?
    private var adLoader: AdLoader?

    func load() {
        guard ad == nil, adLoader == nil else { return }
        let loader = AdLoader(adUnitID: AdsManager.nativeID, rootViewController: nil, adTypes: [.native], options: nil)
        loader.delegate = self
        adLoader = loader
        loader.load(Request())
    }

    nonisolated func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        MainActor.assumeIsolated { ad = nativeAd }
    }

    nonisolated func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {}
}

/// Plain UIKit rather than SwiftUI: AdMob tracks impressions and clicks through
/// the asset views registered on `NativeAdView`, so each asset has to be a real UIView.
private struct NativeCardRepresentable: UIViewRepresentable {
    let ad: NativeAd

    func makeUIView(context: Context) -> NativeCardView { NativeCardView() }

    func updateUIView(_ view: NativeCardView, context: Context) { view.bind(ad) }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: NativeCardView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        let height = uiView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        return CGSize(width: width, height: height)
    }
}

private final class NativeCardView: NativeAdView {
    private let icon = UIImageView()
    private let headline = UILabel()
    private let body = UILabel()
    private let cta = UIButton(type: .custom)

    init() {
        super.init(frame: .zero)
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 18
        layer.cornerCurve = .continuous

        icon.contentMode = .scaleAspectFill
        icon.layer.cornerRadius = 12
        icon.layer.cornerCurve = .continuous
        icon.clipsToBounds = true
        icon.widthAnchor.constraint(equalToConstant: 44).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let badge = PaddedLabel()
        badge.text = "Ad"
        badge.font = .systemFont(ofSize: 9, weight: .bold)
        badge.textColor = .secondaryLabel
        badge.backgroundColor = .tertiarySystemFill
        badge.layer.cornerRadius = 7
        badge.clipsToBounds = true
        badge.setContentHuggingPriority(.required, for: .horizontal)
        badge.setContentCompressionResistancePriority(.required, for: .horizontal)

        headline.font = Self.rounded(.subheadline, weight: .semibold)
        headline.textColor = .label
        headline.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        body.font = .preferredFont(forTextStyle: .caption1)
        body.textColor = .secondaryLabel
        body.numberOfLines = 2

        let titleRow = UIStackView(arrangedSubviews: [badge, headline])
        titleRow.spacing = 6
        titleRow.alignment = .center

        let texts = UIStackView(arrangedSubviews: [titleRow, body])
        texts.axis = .vertical
        texts.spacing = 2

        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = UIColor(named: "AccentColor") ?? .systemPurple
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 14, bottom: 7, trailing: 14)
        cta.configuration = config
        // AdMob handles the tap through the registered view; the button itself must not swallow it.
        cta.isUserInteractionEnabled = false
        cta.setContentHuggingPriority(.required, for: .horizontal)
        cta.setContentCompressionResistancePriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [icon, texts, cta])
        row.spacing = 14
        row.alignment = .center
        row.setCustomSpacing(10, after: texts)
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
        ])

        iconView = icon
        headlineView = headline
        bodyView = body
        callToActionView = cta
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func bind(_ ad: NativeAd) {
        guard nativeAd !== ad else { return }
        headline.text = ad.headline
        body.text = ad.body
        body.isHidden = ad.body?.isEmpty ?? true
        var title = AttributedString(ad.callToAction ?? "")
        title.font = Self.rounded(.caption1, weight: .bold)
        cta.configuration?.attributedTitle = title
        cta.isHidden = ad.callToAction?.isEmpty ?? true
        icon.image = ad.icon?.image
        icon.isHidden = ad.icon == nil
        nativeAd = ad
    }

    private static func rounded(_ style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: style).pointSize, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: 0)
    }
}

private final class PaddedLabel: UILabel {
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: UIEdgeInsets(top: 1, left: 6, bottom: 1, right: 6)))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + 12, height: size.height + 2)
    }
}
