import Foundation
import MultipeerConnectivity

/// Thin transport layer over MultipeerConnectivity. Knows nothing about
/// trivia rules — just discovery, connection, and sending/receiving Codable
/// messages. MultipeerConnectivity automatically negotiates the best
/// available link between nearby devices (Bluetooth or local Wi-Fi), so the
/// app doesn't need to choose a transport itself.
final class MultiplayerService: NSObject, ObservableObject {
    static let serviceType = "wq-trivia"
    /// MultipeerConnectivity sessions are reliable up to about 8 total
    /// participants (Apple's guidance); beyond that, throughput and
    /// discovery become unreliable, so new joins are declined past this cap.
    static let maxPeers = 8

    let myPeerID: MCPeerID
    private let session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    @Published private(set) var connectedPeers: [MCPeerID] = []
    @Published private(set) var discoveredPeers: [MCPeerID] = []

    var onReceive: ((MultiplayerMessage, MCPeerID) -> Void)?
    var onPeerConnected: ((MCPeerID) -> Void)?
    var onPeerDisconnected: ((MCPeerID) -> Void)?
    var onHostDiscovered: ((MCPeerID) -> Void)?
    var onHostLost: ((MCPeerID) -> Void)?

    init(displayName: String) {
        let sanitized = String(displayName.prefix(63))
        myPeerID = MCPeerID(displayName: sanitized.isEmpty ? "Player" : sanitized)
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .none)
        super.init()
        session.delegate = self
    }

    func startHosting() {
        let advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: Self.serviceType)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        self.advertiser = advertiser
    }

    func stopHosting() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
    }

    func startBrowsing() {
        let browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: Self.serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.browser = browser
    }

    func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser = nil
        discoveredPeers = []
    }

    func invite(_ peer: MCPeerID) {
        browser?.invitePeer(peer, to: session, withContext: nil, timeout: 20)
    }

    func send(_ message: MultiplayerMessage, to peers: [MCPeerID]? = nil) {
        guard let data = try? JSONEncoder().encode(message) else { return }
        let targets = peers ?? session.connectedPeers
        guard !targets.isEmpty else { return }
        try? session.send(data, toPeers: targets, with: .reliable)
    }

    func disconnect() {
        session.disconnect()
        stopHosting()
        stopBrowsing()
        connectedPeers = []
    }
}

extension MultiplayerService: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                if !self.connectedPeers.contains(peerID) {
                    self.connectedPeers.append(peerID)
                }
                self.onPeerConnected?(peerID)
            case .notConnected:
                self.connectedPeers.removeAll { $0 == peerID }
                self.onPeerDisconnected?(peerID)
            case .connecting:
                break
            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = try? JSONDecoder().decode(MultiplayerMessage.self, from: data) else { return }
        DispatchQueue.main.async {
            self.onReceive?(message, peerID)
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension MultiplayerService: MCNearbyServiceAdvertiserDelegate {
    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        // +1 accounts for the host itself, which isn't in connectedPeers.
        let hasRoom = connectedPeers.count + 1 < Self.maxPeers
        invitationHandler(hasRoom, hasRoom ? session : nil)
    }
}

extension MultiplayerService: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        DispatchQueue.main.async {
            if !self.discoveredPeers.contains(peerID) {
                self.discoveredPeers.append(peerID)
            }
            self.onHostDiscovered?(peerID)
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.discoveredPeers.removeAll { $0 == peerID }
            self.onHostLost?(peerID)
        }
    }
}
