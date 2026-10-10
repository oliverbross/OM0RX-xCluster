import AppKit
import Foundation

public enum RUMlogControlError: Error, LocalizedError {
    case notInstalled, notRunning, invalidTarget, script(String)
    public var errorDescription: String? {
        switch self {
        case .notInstalled: return "RUMlogNG is not installed."
        case .notRunning: return "Open RUMlogNG and the selected logbook first."
        case .invalidTarget: return "The selected spot contains an invalid callsign, mode, or frequency."
        case .script(let message): return "RUMlogNG rejected the target: \(message)"
        }
    }
}

public struct RUMlogController: @unchecked Sendable {
    public init() {}

    public func send(callsign: String, frequencyKHz: Double, mode: String) throws {
        guard callsign.range(of: #"^[A-Z0-9/]{2,16}$"#, options: .regularExpression) != nil,
              frequencyKHz > 0, frequencyKHz < 100_000_000,
              mode.range(of: #"^[A-Z0-9]{1,12}$"#, options: .regularExpression) != nil else { throw RUMlogControlError.invalidTarget }
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: "de.dl2rum.RUMlogNG") != nil else { throw RUMlogControlError.notInstalled }
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: "de.dl2rum.RUMlogNG").isEmpty else { throw RUMlogControlError.notRunning }
        let rumlogMode = mode == "SSB" ? (frequencyKHz < 14_000 ? "LSB" : "USB") : mode
        let script = """
        tell application id "de.dl2rum.RUMlogNG"
            set callsign to "\(callsign)"
            set mode to "\(rumlogMode)"
            set frequency to \(frequencyKHz)
            set txFrequency to \(frequencyKHz)
            activate
        end tell
        """
        var error: NSDictionary?
        guard NSAppleScript(source: script)?.executeAndReturnError(&error) != nil else {
            throw RUMlogControlError.script(error?[NSAppleScript.errorMessage] as? String ?? "Unknown Apple-event error")
        }
    }
}
