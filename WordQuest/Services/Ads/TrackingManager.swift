import AppTrackingTransparency
import Foundation

/// Wraps Apple's App Tracking Transparency framework — the system-level
/// permission gate required before any app can use tracking-based ad
/// personalization (linking this app's data with other companies' data).
/// Apple explicitly recommends *not* prompting at first launch; this is
/// requested contextually, from a Settings toggle the player opts into.
@MainActor
final class TrackingManager: ObservableObject {
    static let shared = TrackingManager()

    @Published private(set) var status: ATTrackingManager.AuthorizationStatus

    var isAuthorized: Bool { status == .authorized }

    private init() {
        status = ATTrackingManager.trackingAuthorizationStatus
    }

    func refreshStatus() {
        status = ATTrackingManager.trackingAuthorizationStatus
    }

    func requestIfNeeded() {
        guard status == .notDetermined else { return }
        ATTrackingManager.requestTrackingAuthorization { [weak self] newStatus in
            Task { @MainActor in
                self?.status = newStatus
            }
        }
    }
}
