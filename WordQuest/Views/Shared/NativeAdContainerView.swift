import SwiftUI
import GoogleMobileAds

/// Wraps Google's NativeAdView (a plain UIKit container the SDK needs for
/// click/impression tracking) but builds every visible subview ourselves —
/// icon, headline, body, call-to-action — styled to match the app's own
/// card language rather than Google's default template. The small "Ad"
/// badge stays, though: a native ad still has to be identifiable as one.
struct NativeAdContainerView: UIViewRepresentable {
    let nativeAd: NativeAd
    let tintColor: Color

    func makeUIView(context: Context) -> NativeAdView {
        let adView = NativeAdView()

        let icon = UIImageView()
        icon.contentMode = .scaleAspectFill
        icon.clipsToBounds = true
        icon.layer.cornerRadius = 12
        icon.backgroundColor = .secondarySystemBackground
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 44).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let headline = UILabel()
        headline.font = .systemFont(ofSize: 15, weight: .semibold)
        headline.numberOfLines = 1

        let body = UILabel()
        body.font = .systemFont(ofSize: 12, weight: .regular)
        body.textColor = .secondaryLabel
        body.numberOfLines = 2

        let advertiser = UILabel()
        advertiser.font = .systemFont(ofSize: 10, weight: .semibold)
        advertiser.textColor = .tertiaryLabel

        let textStack = UIStackView(arrangedSubviews: [headline, body, advertiser])
        textStack.axis = .vertical
        textStack.spacing = 2

        let cta = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = UIColor(tintColor)
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 12, weight: .bold)
            return outgoing
        }
        cta.configuration = config
        cta.isUserInteractionEnabled = false
        cta.setContentHuggingPriority(.required, for: .horizontal)

        let mainStack = UIStackView(arrangedSubviews: [icon, textStack, cta])
        mainStack.axis = .horizontal
        mainStack.spacing = 12
        mainStack.alignment = .center
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        let adBadge = UILabel()
        adBadge.text = "Ad"
        adBadge.font = .systemFont(ofSize: 9, weight: .heavy)
        adBadge.textColor = .secondaryLabel
        adBadge.backgroundColor = .secondarySystemBackground
        adBadge.textAlignment = .center
        adBadge.layer.cornerRadius = 4
        adBadge.layer.masksToBounds = true
        adBadge.translatesAutoresizingMaskIntoConstraints = false

        adView.addSubview(mainStack)
        adView.addSubview(adBadge)

        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 14),
            mainStack.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -14),
            mainStack.topAnchor.constraint(equalTo: adView.topAnchor, constant: 14),
            mainStack.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -14),

            adBadge.topAnchor.constraint(equalTo: adView.topAnchor, constant: 8),
            adBadge.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -8),
            adBadge.widthAnchor.constraint(equalToConstant: 22),
            adBadge.heightAnchor.constraint(equalToConstant: 14),
        ])

        adView.iconView = icon
        adView.headlineView = headline
        adView.bodyView = body
        adView.advertiserView = advertiser
        adView.callToActionView = cta

        return adView
    }

    func updateUIView(_ nativeAdView: NativeAdView, context: Context) {
        (nativeAdView.headlineView as? UILabel)?.text = nativeAd.headline

        (nativeAdView.bodyView as? UILabel)?.text = nativeAd.body
        nativeAdView.bodyView?.isHidden = nativeAd.body == nil

        (nativeAdView.advertiserView as? UILabel)?.text = nativeAd.advertiser
        nativeAdView.advertiserView?.isHidden = nativeAd.advertiser == nil

        if let button = nativeAdView.callToActionView as? UIButton, let title = nativeAd.callToAction {
            button.configuration?.title = title
        }
        nativeAdView.callToActionView?.isHidden = nativeAd.callToAction == nil

        (nativeAdView.iconView as? UIImageView)?.image = nativeAd.icon?.image
        nativeAdView.iconView?.isHidden = nativeAd.icon == nil

        // Associate last, after every asset view is populated — required
        // for the SDK to register clicks/impressions correctly.
        nativeAdView.nativeAd = nativeAd
    }
}
