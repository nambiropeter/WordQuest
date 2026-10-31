import FBAudienceNetwork
import SwiftUI
import UIKit

/// Meta Audience Network, kept deliberately out of the way of play: an opt-in
/// rewarded video (extra hint), native banner ads drawn as the app's own cards on
/// menu screens (see NativeAdCard), and one interstitial after every 10th solo
/// game of each mode — shown only once the player leaves the result screen, never mid-game.
/// The app is a general-audience game (not in the Kids category), so requests
/// aren't child-directed. It never asks for App Tracking Transparency; on iOS 17+
/// the SDK reads the (never-granted) ATT status itself, so ads are served untracked.
/// Debug builds register the device for Meta's test ads (the Simulator always gets them).
/// Android counterpart: `services/AdsManager.kt`.
@MainActor
final class AdsManager: NSObject, ObservableObject {
    static let shared = AdsManager()

    // Placements in Monetization Manager > WordQuest > iOS app > "First iOS app Ad Space".
    private static let interstitialID = "1012769471850062_1018293261297683"
    static let nativeBannerID = "1012769471850062_1018293377964338"
    private static let rewardedID = "1012769471850062_1018293491297660"

    /// True once the SDK is initialized and requests can go out.
    @Published private(set) var isReady = false
    @Published private(set) var rewardedAvailable = false

    private var started = false

    private var rewardedAd: FBRewardedVideoAd?
    private var rewardedLoading = false
    private var onRewardEarned: (() -> Void)?
    private var onRewardedClosed: (() -> Void)?

    /// Solo games of one mode between interstitials (word search and trivia count separately).
    private static let gamesPerInterstitial = 10
    private var interstitialAd: FBInterstitialAd?
    private var interstitialLoading = false
    private var afterInterstitial: (() -> Void)?

    /// Wait after a failed load (offline, no fill) before asking again; Meta asks for 30s+.
    private static let retryDelay: Duration = .seconds(60)

    func start() {
        guard !started else { return }
        started = true
        #if DEBUG
        FBAdSettings.addTestDevice(FBAdSettings.testDeviceHash())
        #endif
        FBAudienceNetworkAds.initialize(with: nil) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                guard result.isSuccess else {
                    print("Audience Network init failed: \(result.message)")
                    return
                }
                self.isReady = true
                self.loadRewarded()
                self.loadInterstitial()
            }
        }
    }

    private func loadRewarded() {
        guard rewardedAd == nil, !rewardedLoading else { return }
        rewardedLoading = true
        let ad = FBRewardedVideoAd(placementID: Self.rewardedID)
        ad.delegate = self
        rewardedAd = ad
        ad.load()
    }

    private func loadInterstitial() {
        guard interstitialAd == nil, !interstitialLoading else { return }
        interstitialLoading = true
        let ad = FBInterstitialAd(placementID: Self.interstitialID)
        ad.delegate = self
        interstitialAd = ad
        ad.load()
    }

    private func retry(_ load: @escaping @MainActor () -> Void) {
        Task {
            try? await Task.sleep(for: Self.retryDelay)
            load()
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
        let ad = interstitialLoading ? nil : interstitialAd
        guard played >= Self.gamesPerInterstitial, let ad, ad.isAdValid else {
            defaults.set(played, forKey: key)
            // Meta ads expire after about an hour; drop an expired one so a fresh one loads.
            if let ad, !ad.isAdValid, isReady {
                interstitialAd = nil
                loadInterstitial()
            }
            then()
            return
        }
        defaults.set(0, forKey: key)
        interstitialAd = nil
        afterInterstitial = then
        if !ad.show(fromRootViewController: Self.topViewController) {
            afterInterstitial = nil
            then()
            loadInterstitial()
        }
    }

    /// Shows the rewarded ad if one is loaded. `onReward` runs only if the player
    /// watched it through; `onFinished` runs once the ad is gone either way.
    func showRewarded(onReward: @escaping () -> Void, onFinished: @escaping () -> Void = {}) {
        guard !rewardedLoading, let ad = rewardedAd, ad.isAdValid, let root = Self.topViewController else {
            // Meta ads expire after about an hour; drop an expired one so a fresh one loads.
            if !rewardedLoading, let ad = rewardedAd, !ad.isAdValid {
                rewardedAd = nil
                rewardedAvailable = false
            }
            loadRewarded()
            onFinished()
            return
        }
        rewardedAd = nil
        rewardedAvailable = false
        onRewardEarned = onReward
        onRewardedClosed = onFinished
        if !ad.show(fromRootViewController: root, animated: true) {
            onRewardEarned = nil
            onRewardedClosed = nil
            loadRewarded()
            onFinished()
        }
    }

    /// The view controller full-screen ads present from: whatever is on top of the key window.
    static var topViewController: UIViewController? {
        var top = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .windows.first(where: \.isKeyWindow)?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

// Audience Network calls its delegates on the main thread.
extension AdsManager: FBInterstitialAdDelegate {
    nonisolated func interstitialAdDidLoad(_ interstitialAd: FBInterstitialAd) {
        MainActor.assumeIsolated { interstitialLoading = false }
    }

    nonisolated func interstitialAd(_ interstitialAd: FBInterstitialAd, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            print("Interstitial failed: \(error.localizedDescription)")
            interstitialLoading = false
            if self.interstitialAd === interstitialAd { self.interstitialAd = nil }
            retry { [weak self] in self?.loadInterstitial() }
        }
    }

    nonisolated func interstitialAdDidClose(_ interstitialAd: FBInterstitialAd) {
        MainActor.assumeIsolated {
            afterInterstitial?()
            afterInterstitial = nil
            loadInterstitial()
        }
    }
}

extension AdsManager: FBRewardedVideoAdDelegate {
    nonisolated func rewardedVideoAdDidLoad(_ rewardedVideoAd: FBRewardedVideoAd) {
        MainActor.assumeIsolated {
            rewardedLoading = false
            rewardedAvailable = rewardedAd === rewardedVideoAd
        }
    }

    nonisolated func rewardedVideoAd(_ rewardedVideoAd: FBRewardedVideoAd, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            print("Rewarded failed to load: \(error.localizedDescription)")
            rewardedLoading = false
            if rewardedAd === rewardedVideoAd { rewardedAd = nil }
            rewardedAvailable = false
            retry { [weak self] in self?.loadRewarded() }
        }
    }

    nonisolated func rewardedVideoAdVideoComplete(_ rewardedVideoAd: FBRewardedVideoAd) {
        MainActor.assumeIsolated {
            onRewardEarned?()
            onRewardEarned = nil
        }
    }

    nonisolated func rewardedVideoAdDidClose(_ rewardedVideoAd: FBRewardedVideoAd) {
        MainActor.assumeIsolated {
            onRewardedClosed?()
            onRewardedClosed = nil
            onRewardEarned = nil
            loadRewarded()
        }
    }
}
