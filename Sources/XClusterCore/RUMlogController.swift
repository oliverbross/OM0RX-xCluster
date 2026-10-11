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

    public func send(callsign: String, frequencyKHz: Double, mode: String, note: String? = nil) throws {
        guard callsign.range(of: #"^[A-Z0-9/]{2,16}$"#, options: .regularExpression) != nil,
              frequencyKHz > 0, frequencyKHz < 100_000_000,
              mode.range(of: #"^[A-Z0-9]{1,12}$"#, options: .regularExpression) != nil else { throw RUMlogControlError.invalidTarget }
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: "de.dl2rum.RUMlogNG") != nil else { throw RUMlogControlError.notInstalled }
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: "de.dl2rum.RUMlogNG").isEmpty else { throw RUMlogControlError.notRunning }
        let rumlogMode = mode == "SSB" ? (frequencyKHz < 14_000 ? "LSB" : "USB") : mode
        let noteCommand = note.map { "set note to \"\(Self.appleScriptString($0))\"" } ?? ""
        let script = """
        tell application id "de.dl2rum.RUMlogNG"
            set callsign to "\(callsign)"
            set mode to "\(rumlogMode)"
            set frequency to \(frequencyKHz)
            \(noteCommand)
            set txFrequency to \(frequencyKHz)
            activate
        end tell
        """
        var error: NSDictionary?
        guard NSAppleScript(source: script)?.executeAndReturnError(&error) != nil else {
            throw RUMlogControlError.script(error?[NSAppleScript.errorMessage] as? String ?? "Unknown Apple-event error")
        }
    }

    static func appleScriptString(_ value: String) -> String {
        var escaped = ""
        for scalar in value.unicodeScalars {
            switch scalar.value {
            case 0x22: escaped.append("\\\"")
            case 0x5c: escaped.append("\\\\")
            case 0x00..<0x20, 0x7f: escaped.append(" ")
            default: escaped.unicodeScalars.append(scalar)
            }
        }
        return escaped.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
