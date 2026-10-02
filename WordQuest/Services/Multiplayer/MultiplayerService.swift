import Foundation
import Network

/// Thin transport layer for local multiplayer. Knows nothing about trivia
/// rules — just discovery, connection, and sending/receiving
/// `MultiplayerMessage`s.
///
/// Both platforms speak the same open protocol so iPhones and Android phones
/// can play together: the host advertises a Bonjour service of type
/// `serviceType` (via `NWListener` here, `NsdManager` on Android) and accepts
/// plain TCP connections; every message is one line of UTF-8 JSON terminated
/// by `\n`. Players therefore need to be on the same Wi-Fi network (or one
/// phone's hotspot) — MultipeerConnectivity and Android's Nearby Connections
/// can't talk to each other.
final class MultiplayerService: ObservableObject {
    /// Must match `LocalMultiplayerService.SERVICE_TYPE` on Android and
    /// `NSBonjourServices` in Info.plist.
    static let serviceType = "_wq-trivia._tcp"
    /// Host + guests — mirrors Android's `LocalMultiplayerService.MAX_PEERS`.
    static let maxPeers = 8

    struct Peer: Hashable, Identifiable {
        let id: String
    }

    struct DiscoveredHost: Hashable, Identifiable {
        let id: String
        let name: String
        let endpoint: NWEndpoint
    }

    private let displayName: String
    private var listener: NWListener?
    private var browser: NWBrowser?
    private var connections: [String: NWConnection] = [:]
    private var buffers: [String: Data] = [:]

    @Published private(set) var connectedPeers: [Peer] = []
    @Published private(set) var discoveredHosts: [DiscoveredHost] = []

    var onReceive: ((MultiplayerMessage, Peer) -> Void)?
    var onPeerConnected: ((Peer) -> Void)?
    var onPeerDisconnected: ((Peer) -> Void)?
    var onHostDiscovered: ((DiscoveredHost) -> Void)?
    var onHostLost: ((DiscoveredHost) -> Void)?

    init(displayName: String) {
        let sanitized = String(displayName.prefix(63))
        self.displayName = sanitized.isEmpty ? "Player" : sanitized
    }

    // MARK: - Host

    func startHosting() {
        do {
            let listener = try NWListener(using: Self.tcpParameters())
            listener.service = NWListener.Service(name: displayName, type: Self.serviceType)
            listener.stateUpdateHandler = { state in
                if case .failed(let error) = state {
                    print("Multiplayer: listener failed: \(error)")
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                guard let self else { return connection.cancel() }
                // +1 accounts for the host itself, which isn't in connections.
                guard self.connections.count + 1 < Self.maxPeers else {
                    connection.cancel()
                    return
                }
                self.attach(connection, id: UUID().uuidString)
            }
            listener.start(queue: .main)
            self.listener = listener
        } catch {
            print("Multiplayer: could not start hosting: \(error)")
        }
    }

    func stopHosting() {
        listener?.cancel()
        listener = nil
    }

    // MARK: - Guest

    func startBrowsing() {
        let browser = NWBrowser(for: .bonjour(type: Self.serviceType, domain: nil), using: Self.tcpParameters())
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self else { return }
            let hosts: [DiscoveredHost] = results.compactMap { result in
                guard case let .service(name, _, _, _) = result.endpoint else { return nil }
                return DiscoveredHost(id: name, name: name, endpoint: result.endpoint)
            }
            let lost = self.discoveredHosts.filter { old in !hosts.contains { $0.id == old.id } }
            let found = hosts.filter { new in !self.discoveredHosts.contains { $0.id == new.id } }
            self.discoveredHosts = hosts
            lost.forEach { self.onHostLost?($0) }
            found.forEach { self.onHostDiscovered?($0) }
        }
        browser.stateUpdateHandler = { state in
            if case .failed(let error) = state {
                print("Multiplayer: browser failed: \(error)")
            }
        }
        browser.start(queue: .main)
        self.browser = browser
    }

    func stopBrowsing() {
        browser?.cancel()
        browser = nil
        discoveredHosts = []
    }

    func connect(to host: DiscoveredHost) {
        attach(NWConnection(to: host.endpoint, using: Self.tcpParameters()), id: host.id)
    }

    // MARK: - Messaging

    func send(_ message: MultiplayerMessage, to peers: [Peer]? = nil) {
        var data: Data
        do {
            data = try JSONEncoder().encode(message)
        } catch {
            print("Multiplayer: failed to encode \(message): \(error.localizedDescription)")
            return
        }
        data.append(0x0A)
        let targets = peers?.map(\.id) ?? connectedPeers.map(\.id)
        for id in targets {
            connections[id]?.send(content: data, completion: .contentProcessed { error in
                if let error {
                    // A dropped send used to vanish silently, which made a stalled
                    // round impossible to tell apart from a peer not answering.
                    print("Multiplayer: send failed: \(error)")
                }
            })
        }
    }

    func disconnect() {
        stopHosting()
        stopBrowsing()
        for connection in connections.values { connection.cancel() }
        connections = [:]
        buffers = [:]
        connectedPeers = []
    }

    // MARK: - Connections

    private static func tcpParameters() -> NWParameters {
        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true
        return NWParameters(tls: nil, tcp: tcp)
    }

    private func attach(_ connection: NWConnection, id: String) {
        connections[id] = connection
        let peer = Peer(id: id)
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                if !self.connectedPeers.contains(peer) {
                    self.connectedPeers.append(peer)
                }
                self.onPeerConnected?(peer)
            case .failed(let error):
                print("Multiplayer: connection failed: \(error)")
                connection.cancel()
                self.drop(id)
            case .cancelled:
                self.drop(id)
            default:
                break
            }
        }
        receive(on: connection, id: id)
        connection.start(queue: .main)
    }

    private func receive(on connection: NWConnection, id: String) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.buffers[id, default: Data()].append(data)
                self.drainLines(for: id)
            }
            if isComplete || error != nil {
                connection.cancel()
            } else {
                self.receive(on: connection, id: id)
            }
        }
    }

    private func drainLines(for id: String) {
        guard var buffer = buffers[id] else { return }
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = Data(buffer[buffer.startIndex..<newline])
            buffer.removeSubrange(buffer.startIndex...newline)
            guard !line.isEmpty else { continue }
            do {
                let message = try JSONDecoder().decode(MultiplayerMessage.self, from: line)
                onReceive?(message, Peer(id: id))
            } catch {
                print("Multiplayer: dropping undecodable message: \(error)")
            }
        }
        // A handler may have disconnected this peer mid-loop; don't resurrect its buffer.
        if connections[id] != nil { buffers[id] = buffer }
    }

    private func drop(_ id: String) {
        guard connections.removeValue(forKey: id) != nil else { return }
        buffers[id] = nil
        let peer = Peer(id: id)
        let wasConnected = connectedPeers.contains(peer)
        connectedPeers.removeAll { $0 == peer }
        if wasConnected {
            onPeerDisconnected?(peer)
        }
    }
}
