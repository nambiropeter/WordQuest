import GoogleMobileAds
import UIKit

/// Loads a single native ad for the "suggested for you" slot on Home. Native
/// ads hand you the raw content (headline, body, icon, call-to-action) and
/// let *you* build the UI around it — that's the deliberate choice here,
/// instead of a traditional banner/interstitial: the ad renders inside the
/// same card treatment as the app's own content, so it's present without
/// shouting.
///
/// Ships wired to Google's public test ad unit ID, which is safe to build
/// and run today with no AdMob account. Swap `nativeAdUnitID` for a real ad
/// unit ID from your own AdMob account before release — test ads are not
/// eligible for real payouts and Google will flag production traffic on
/// test IDs.
@MainActor
final class AdsManager: NSObject, ObservableObject {
    static let shared = AdsManager()

    static let nativeAdUnitID = "ca-app-pub-3940256099942544/3986624511"

    @Published private(set) var nativeAd: NativeAd?

    private var adLoader: AdLoader?
    private var didStartSDK = false

    private override init() {
        super.init()
    }

    func start() {
        guard !didStartSDK else { return }
        didStartSDK = true
        MobileAds.shared.start()
    }

    /// `personalized` should reflect the player's actual App Tracking
    /// Transparency status — when it's false, the request is explicitly
    /// marked non-personalized rather than silently guessing.
    func loadAd(personalized: Bool) {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?.rootViewController else {
            print("Native ad load skipped: no key window yet")
            return
        }

        let loader = AdLoader(
            adUnitID: Self.nativeAdUnitID,
            rootViewController: root,
            adTypes: [.native],
            options: nil
        )
        loader.delegate = self
        adLoader = loader

        let request = Request()
        let extras = Extras()
        extras.additionalParameters = ["npa": personalized ? "0" : "1"]
        request.register(extras)
        loader.load(request)
    }
}

extension AdsManager: AdLoaderDelegate {
    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        print("Native ad failed to load: \(error.localizedDescription)")
    }
}

extension AdsManager: NativeAdLoaderDelegate {
    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        print("Native ad loaded: \(nativeAd.headline ?? "(no headline)")")
        self.nativeAd = nativeAd
    }
}
