import FBAudienceNetwork
import SwiftUI
import UIKit

/// A Meta native banner ad drawn as one of the app's own cards — same shape,
/// spacing and colors as Home's `SuggestedCard` — with the advertiser name, a
/// "Sponsored" label and the AdChoices icon (all required by Audience Network
/// policy). Takes no space until an ad has actually loaded.
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
private final class NativeAdLoader: NSObject, ObservableObject, FBNativeBannerAdDelegate {
    @Published private(set) var ad: FBNativeBannerAd?
    private var pending: FBNativeBannerAd?

    func load() {
        guard ad == nil, pending == nil else { return }
        let banner = FBNativeBannerAd(placementID: AdsManager.nativeBannerID)
        banner.delegate = self
        pending = banner
        banner.loadAd()
    }

    nonisolated func nativeBannerAdDidLoad(_ nativeBannerAd: FBNativeBannerAd) {
        MainActor.assumeIsolated {
            pending = nil
            if nativeBannerAd.isAdValid { ad = nativeBannerAd }
        }
    }

    nonisolated func nativeBannerAd(_ nativeBannerAd: FBNativeBannerAd, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            print("Native banner failed: \(error.localizedDescription)")
            pending = nil
        }
    }
}

/// Plain UIKit rather than SwiftUI: Audience Network tracks impressions and clicks
/// through the views registered with the ad, so each asset has to be a real UIView.
private struct NativeCardRepresentable: UIViewRepresentable {
    let ad: FBNativeBannerAd

    func makeUIView(context: Context) -> NativeCardView { NativeCardView() }

    func updateUIView(_ view: NativeCardView, context: Context) { view.bind(ad) }

    static func dismantleUIView(_ view: NativeCardView, coordinator: ()) { view.unbind() }

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

private final class NativeCardView: UIView {
    private let icon = FBAdIconView()
    private let badge = PaddedLabel()
    private let headline = UILabel()
    private let body = UILabel()
    private let cta = UIButton(type: .custom)
    private let adOptions = FBAdOptionsView()
    private weak var boundAd: FBNativeBannerAd?

    init() {
        super.init(frame: .zero)
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 18
        layer.cornerCurve = .continuous

        icon.layer.cornerRadius = 12
        icon.layer.cornerCurve = .continuous
        icon.clipsToBounds = true
        icon.widthAnchor.constraint(equalToConstant: 44).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 44).isActive = true

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

        adOptions.useSingleIcon = true
        adOptions.foregroundColor = .secondaryLabel
        adOptions.translatesAutoresizingMaskIntoConstraints = false
        adOptions.widthAnchor.constraint(equalToConstant: FBAdOptionsViewWidth).isActive = true
        adOptions.heightAnchor.constraint(equalToConstant: FBAdOptionsViewHeight).isActive = true

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
        // No action of its own: Audience Network attaches its tap handling to the registered clickable views.
        cta.setContentHuggingPriority(.required, for: .horizontal)
        cta.setContentCompressionResistancePriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [icon, texts, cta])
        row.spacing = 14
        row.alignment = .center
        row.setCustomSpacing(10, after: texts)
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        // AdChoices sits in the card's top-right corner, clear of the call-to-action.
        addSubview(adOptions)
        NSLayoutConstraint.activate([
            adOptions.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            adOptions.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func bind(_ ad: FBNativeBannerAd) {
        guard boundAd !== ad else { return }
        boundAd?.unregisterView()
        badge.text = ad.sponsoredTranslation.flatMap { $0.isEmpty ? nil : $0 } ?? "Sponsored"
        headline.text = ad.advertiserName
        let bodyText = ad.bodyText.flatMap { $0.isEmpty ? nil : $0 } ?? ad.socialContext
        body.text = bodyText
        body.isHidden = bodyText?.isEmpty ?? true
        var title = AttributedString(ad.callToAction ?? "")
        title.font = Self.rounded(.caption1, weight: .bold)
        cta.configuration?.attributedTitle = title
        cta.isHidden = ad.callToAction?.isEmpty ?? true
        ad.registerView(forInteraction: self, iconView: icon, viewController: AdsManager.topViewController,
                        clickableViews: [icon, headline, cta])
        adOptions.nativeAd = ad
        boundAd = ad
    }

    func unbind() {
        boundAd?.unregisterView()
        boundAd = nil
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
