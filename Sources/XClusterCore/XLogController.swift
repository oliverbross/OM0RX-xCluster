import AppKit
import Foundation

public enum XLogControlError: Error, LocalizedError {
    case invalidTarget
    case unavailable

    public var errorDescription: String? {
        switch self {
        case .invalidTarget: return "The selected spot contains an invalid callsign, mode, or frequency."
        case .unavailable: return "OM0RX-xLog could not open the selected spot."
        }
    }
}

public struct XLogController: Sendable {
    public init() {}

    @MainActor
    public func send(callsign: String, frequencyKHz: Double, mode: String, note: String? = nil) throws {
        let url = try url(callsign: callsign, frequencyKHz: frequencyKHz, mode: mode, note: note)
        guard NSWorkspace.shared.open(url) else { throw XLogControlError.unavailable }
    }

    public func url(callsign: String, frequencyKHz: Double, mode: String, note: String? = nil) throws -> URL {
        guard callsign.range(of: #"^[A-Z0-9/]{2,16}$"#, options: .regularExpression) != nil,
              frequencyKHz > 0, frequencyKHz < 100_000_000,
              mode.range(of: #"^[A-Z0-9]{1,12}$"#, options: .regularExpression) != nil else {
            throw XLogControlError.invalidTarget
        }
        var components = URLComponents()
        components.scheme = "om0rx-xlog"
        components.host = "spot"
        components.queryItems = [
            URLQueryItem(name: "call", value: callsign),
            URLQueryItem(name: "frequency", value: String(format: "%.3f", frequencyKHz)),
            URLQueryItem(name: "mode", value: mode),
        ]
        if let note, !note.isEmpty { components.queryItems?.append(URLQueryItem(name: "comment", value: note)) }
        guard let url = components.url else { throw XLogControlError.unavailable }
        return url
    }
}
