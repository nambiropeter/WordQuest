import GoogleMobileAds
import SwiftUI
import UIKit
import UserMessagingPlatform

/// AdMob, kept deliberately out of the way of play: an opt-in rewarded ad (extra
/// hint), native ads drawn as the app's own cards on menu screens (see
/// NativeAdCard), and one interstitial after every 10th solo game of each mode —
/// shown only once the player leaves the result screen, never mid-game.
/// The app targets all ages, so every request is child-directed and capped at
/// G-rated content; the app never asks for App Tracking Transparency.
/// Debug builds use Google's sample ad units so test taps never hit real inventory.
/// Android counterpart: `services/AdsManager.kt`.
@MainActor
final class AdsManager: NSObject, ObservableObject {
    static let shared = AdsManager()

    #if DEBUG
    static let nativeID = "ca-app-pub-3940256099942544/3986624511"
    private static let interstitialID = "ca-app-pub-3940256099942544/4411468910"
    private static let rewardedID = "ca-app-pub-3940256099942544/1712485313"
    #else
    static let nativeID = "ca-app-pub-7633404067070211/5350162423"
    private static let interstitialID = "ca-app-pub-7633404067070211/1366771106"
    private static let rewardedID = "ca-app-pub-7633404067070211/4352027096"
    #endif

    /// True once consent allows requests and the SDK is started.
    @Published private(set) var isReady = false
    @Published private(set) var rewardedAvailable = false
    /// True where the law (e.g. GDPR) requires a way to revisit the consent choice; drives Settings' row.
    @Published private(set) var privacyOptionsRequired = false

    private var rewardedAd: RewardedAd?
    private var rewardedLoading = false
    private var started = false
    private var onFinished: (() -> Void)?

    /// Solo games of one mode between interstitials (word search and trivia count separately).
    private static let gamesPerInterstitial = 10
    private var interstitialAd: InterstitialAd?
    private var interstitialLoading = false
    private var afterInterstitial: (() -> Void)?

    /// Gathers GDPR/US-state consent through Google's UMP form (shown only where
    /// required, and only if a message is configured in AdMob), then starts the SDK.
    func start() {
        let parameters = RequestParameters()
        parameters.isTaggedForUnderAgeOfConsent = true
        ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { [weak self] _ in
            Task { @MainActor in
                try? await ConsentForm.loadAndPresentIfRequired(from: nil)
                self?.privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
                self?.startIfAllowed()
            }
        }
        // Consent from a previous session lets ads start without waiting on the network.
        startIfAllowed()
    }

    /// Re-opens Google's consent form so the player can change their ad privacy choice.
    func showPrivacyOptions() {
        Task { try? await ConsentForm.presentPrivacyOptionsForm(from: nil) }
    }

    private func startIfAllowed() {
        guard ConsentInformation.shared.canRequestAds, !started else { return }
        started = true
        MobileAds.shared.requestConfiguration.ageRestrictedTreatment = .child
        MobileAds.shared.requestConfiguration.maxAdContentRating = .general
        MobileAds.shared.start { [weak self] _ in
            Task { @MainActor in
                self?.isReady = true
                self?.loadRewarded()
                self?.loadInterstitial()
            }
        }
    }

    private func loadRewarded() {
        guard rewardedAd == nil, !rewardedLoading else { return }
        rewardedLoading = true
        Task {
            defer { rewardedLoading = false }
            do {
                let ad = try await RewardedAd.load(with: Self.rewardedID, request: Request())
                ad.fullScreenContentDelegate = self
                rewardedAd = ad
                rewardedAvailable = true
            } catch {
                rewardedAd = nil
                rewardedAvailable = false
            }
        }
    }

    private func loadInterstitial() {
        guard interstitialAd == nil, !interstitialLoading else { return }
        interstitialLoading = true
        Task {
            defer { interstitialLoading = false }
            do {
                let ad = try await InterstitialAd.load(with: Self.interstitialID, request: Request())
                ad.fullScreenContentDelegate = self
                interstitialAd = ad
            } catch {
                interstitialAd = nil
            }
        }
    }

    /// Call when the player leaves a finished solo game of `mode`. Every 10th game
    /// of that mode shows an interstitial first; `then` (the navigation they tapped)
    /// runs once it closes, or straight away otherwise. If no ad is loaded on the
    /// 10th game, the count stays due so the next game tries again.
    func afterSoloGame(_ mode: GameMode, then: @escaping () -> Void) {
        let defaults = UserDefaults.standard
        let key = "wq.ads.\(mode.rawValue)GamesSinceInterstitial"
        let played = defaults.integer(forKey: key) + 1
        guard played >= Self.gamesPerInterstitial, let ad = interstitialAd else {
            defaults.set(played, forKey: key)
            if interstitialAd == nil, isReady { loadInterstitial() }
            then()
            return
        }
        defaults.set(0, forKey: key)
        interstitialAd = nil
        afterInterstitial = then
        ad.present(from: nil)
    }

    private func finishInterstitial() {
        afterInterstitial?()
        afterInterstitial = nil
        loadInterstitial()
    }

    /// Shows the rewarded ad if one is loaded. `onReward` runs only if the player
    /// watched it through; `onFinished` runs once the ad is gone either way.
    func showRewarded(onReward: @escaping () -> Void, onFinished: @escaping () -> Void = {}) {
        guard let ad = rewardedAd else {
            loadRewarded()
            onFinished()
            return
        }
        rewardedAd = nil
        rewardedAvailable = false
        self.onFinished = onFinished
        ad.present(from: nil) { onReward() }
    }

    private func finishRewarded() {
        onFinished?()
        onFinished = nil
        loadRewarded()
    }
}

extension AdsManager: FullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        let isInterstitial = ad is InterstitialAd
        Task { @MainActor in isInterstitial ? finishInterstitial() : finishRewarded() }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        let isInterstitial = ad is InterstitialAd
        Task { @MainActor in isInterstitial ? finishInterstitial() : finishRewarded() }
    }
}
