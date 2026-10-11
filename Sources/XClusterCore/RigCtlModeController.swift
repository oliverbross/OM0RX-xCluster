import Foundation
import Network

public enum RigCtlModeError: Error, LocalizedError {
    case invalidEndpoint
    case timeout
    case connection(String)
    case rejected(String)

    public var errorDescription: String? {
        switch self {
        case .invalidEndpoint: return "Invalid RigCtlD host or port"
        case .timeout: return "RigCtlD did not reply"
        case .connection(let message): return "RigCtlD connection failed: \(message)"
        case .rejected(let reply): return "RigCtlD rejected the mode (\(reply))"
        }
    }
}

public struct RigCtlModeController: Sendable {
    public let host: String
    public let port: Int

    public init(host: String = "127.0.0.1", port: Int = 14532) {
        self.host = host
        self.port = port
    }

    @discardableResult
    public func setMode(for spotMode: String, frequencyKHz: Double) throws -> String {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty, let endpointPort = NWEndpoint.Port(rawValue: UInt16(clamping: port)), port > 0, port <= 65_535 else {
            throw RigCtlModeError.invalidEndpoint
        }
        let mode = Self.radioMode(for: spotMode, frequencyKHz: frequencyKHz)
        let connection = NWConnection(host: NWEndpoint.Host(trimmedHost), port: endpointPort, using: .tcp)
        let gate = RigCtlResponseGate()
        let queue = DispatchQueue(label: "com.oliverbross.xcluster.rigctl")

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                connection.send(content: Data("M \(mode) 0\n".utf8), completion: .contentProcessed { error in
                    if let error {
                        gate.finish(.failure(.connection(error.localizedDescription)))
                        return
                    }
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 1_024) { data, _, _, error in
                        if let error {
                            gate.finish(.failure(.connection(error.localizedDescription)))
                        } else {
                            let reply = data.flatMap { String(data: $0, encoding: .utf8) }?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                            gate.finish(reply.contains("RPRT 0") ? .success(mode) : .failure(.rejected(reply.isEmpty ? "empty reply" : reply)))
                        }
                    }
                })
            case .failed(let error): gate.finish(.failure(.connection(error.localizedDescription)))
            case .cancelled: break
            default: break
            }
        }
        connection.start(queue: queue)
        let result = gate.wait(timeout: .now() + 2.0)
        connection.cancel()
        return try result.get()
    }

    public static func radioMode(for spotMode: String, frequencyKHz: Double) -> String {
        let mode = spotMode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if mode == "SSB" { return frequencyKHz < 14_000 ? "LSB" : "USB" }
        if ["FT8", "FT4", "FT2", "JT65", "JT9", "PSK", "DIGI", "MFSK", "OLIVIA"].contains(mode) { return "DIGU" }
        return mode
    }
}

private final class RigCtlResponseGate: @unchecked Sendable {
    private let lock = NSLock()
    private let semaphore = DispatchSemaphore(value: 0)
    private var result: Result<String, RigCtlModeError>?

    func finish(_ result: Result<String, RigCtlModeError>) {
        let shouldSignal = lock.withLock {
            guard self.result == nil else { return false }
            self.result = result
            return true
        }
        if shouldSignal { semaphore.signal() }
    }

    func wait(timeout: DispatchTime) -> Result<String, RigCtlModeError> {
        guard semaphore.wait(timeout: timeout) == .success else { return .failure(.timeout) }
        return lock.withLock { result ?? .failure(.timeout) }
    }
}
