import Foundation
import Network

public final class ClusterHub: @unchecked Sendable {
    public typealias SpotHandler = @Sendable (RawSpot) -> Void
    public typealias StateHandler = @Sendable (UUID, ConnectionState, String?) -> Void

    private let lock = NSLock()
    private var connections: [UUID: ClusterConnection] = [:]

    public init() {}

    public func start(servers: [ClusterServer], reconnect: Bool, onSpot: @escaping SpotHandler, onState: @escaping StateHandler) {
        stop()
        var next: [UUID: ClusterConnection] = [:]
        for server in servers where server.enabled {
            let connection = ClusterConnection(server: server, password: SettingsStore.shared.password(for: server.id), reconnect: reconnect, onSpot: onSpot, onState: onState)
            next[server.id] = connection
            connection.start()
        }
        lock.lock(); connections = next; lock.unlock()
    }

    public func stop() {
        lock.lock(); let current = connections.values; connections.removeAll(); lock.unlock()
        current.forEach { $0.stop() }
    }
}

private final class ClusterConnection: @unchecked Sendable {
    private let server: ClusterServer
    private let password: String
    private let reconnect: Bool
    private let onSpot: ClusterHub.SpotHandler
    private let onState: ClusterHub.StateHandler
    private let queue: DispatchQueue
    private var connection: NWConnection?
    private var buffer = Data()
    private var stopped = false
    private var retry = 0

    init(server: ClusterServer, password: String, reconnect: Bool, onSpot: @escaping ClusterHub.SpotHandler, onState: @escaping ClusterHub.StateHandler) {
        self.server = server; self.password = password; self.reconnect = reconnect; self.onSpot = onSpot; self.onState = onState
        queue = DispatchQueue(label: "com.oliverbross.xcluster.\(server.id.uuidString)")
    }

    func start() { queue.async { self.connect() } }
    func stop() { queue.async { self.stopped = true; self.connection?.cancel(); self.connection = nil } }

    private func connect() {
        guard !stopped, let port = NWEndpoint.Port(rawValue: UInt16(clamping: server.port)) else { return }
        onState(server.id, .connecting, nil)
        let connection = NWConnection(host: NWEndpoint.Host(server.host), port: port, using: .tcp)
        self.connection = connection
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self, let connection else { return }
            self.queue.async {
                switch state {
                case .ready:
                    self.retry = 0; self.onState(self.server.id, .connected, nil)
                    self.sendLogin(on: connection); self.receive(on: connection)
                case .failed(let error): self.disconnected(error.localizedDescription)
                case .cancelled: if !self.stopped { self.disconnected(nil) }
                default: break
                }
            }
        }
        connection.start(queue: queue)
    }

    private func sendLogin(on connection: NWConnection) {
        queue.asyncAfter(deadline: .now() + 0.45) { [self] in
            guard !stopped else { return }
            var login = server.callsign.uppercased() + "\r\n"
            if !password.isEmpty { login += password + "\r\n" }
            connection.send(content: Data(login.utf8), completion: .contentProcessed { [weak self] error in
                if let error { self?.queue.async { self?.disconnected(error.localizedDescription) } }
            })
        }
    }

    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 32_768) { [weak self, weak connection] data, _, complete, error in
            guard let self, let connection else { return }
            self.queue.async {
                if let data { self.consume(data) }
                if let error { self.disconnected(error.localizedDescription); return }
                if complete { self.disconnected("Cluster closed the connection"); return }
                if !self.stopped { self.receive(on: connection) }
            }
        }
    }

    private func consume(_ data: Data) {
        buffer.append(Self.stripTelnet(data))
        while let newline = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer.prefix(upTo: newline)
            buffer.removeSubrange(...newline)
            guard let line = String(data: lineData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !line.isEmpty else { continue }
            if let spot = ClusterLineParser.parse(line, clusterID: server.id, clusterName: server.name) { onSpot(spot) }
        }
    }

    private func disconnected(_ reason: String?) {
        connection?.cancel(); connection = nil
        guard !stopped else { onState(server.id, .disconnected, nil); return }
        onState(server.id, reason == nil ? .disconnected : .failed, reason)
        guard reconnect else { return }
        let delays = [2, 5, 10, 20, 30, 60]
        let delay = delays[min(retry, delays.count - 1)]; retry += 1
        queue.asyncAfter(deadline: .now() + .seconds(delay)) { [weak self] in self?.connect() }
    }

    private static func stripTelnet(_ input: Data) -> Data {
        let bytes = [UInt8](input); var output: [UInt8] = []; var index = 0
        while index < bytes.count {
            if bytes[index] == 255 {
                if index + 1 < bytes.count, bytes[index + 1] == 255 { output.append(255); index += 2 }
                else { index += min(3, bytes.count - index) }
            } else { output.append(bytes[index]); index += 1 }
        }
        return Data(output)
    }
}
