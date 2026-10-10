import Foundation
import SQLite3

public enum LogbookError: Error, LocalizedError {
    case missing(String), open(String), query(String)
    public var errorDescription: String? {
        switch self {
        case .missing(let path): return "RUMlog logbook not found at \(path)."
        case .open(let message): return "Could not open the RUMlog logbook read-only: \(message)"
        case .query(let message): return "Could not read the RUMlog logbook: \(message)"
        }
    }
}

public struct LogbookIndex: Sendable {
    public let loadedAt: Date
    public let modifiedAt: Date?
    public let recordCount: Int
    private let recordsByCall: [String: [QSORecord]]
    private let callBands: [String: Set<String>]
    private let callModes: [String: Set<String>]
    private let confirmedCallBandModes: Set<String>
    private let dxccBands: [Int: Set<String>]
    private let dxccModes: [Int: Set<String>]
    private let workedDXCC: Set<Int>
    private let confirmedDXCC: Set<Int>
    private let confirmedDXCCBandModes: Set<String>

    public static let empty = LogbookIndex(loadedAt: .distantPast, modifiedAt: nil, recordCount: 0, recordsByCall: [:], callBands: [:], callModes: [:], confirmedCallBandModes: [], dxccBands: [:], dxccModes: [:], workedDXCC: [], confirmedDXCC: [], confirmedDXCCBandModes: [])

    public static func load(url: URL) throws -> LogbookIndex {
        guard FileManager.default.fileExists(atPath: url.path) else { throw LogbookError.missing(url.path) }
        var database: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX
        guard sqlite3_open_v2(url.path, &database, flags, nil) == SQLITE_OK, let database else {
            let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown SQLite error"
            if let database { sqlite3_close(database) }
            throw LogbookError.open(message)
        }
        defer { sqlite3_close(database) }
        sqlite3_busy_timeout(database, 2_000)
        guard sqlite3_exec(database, "PRAGMA query_only=ON", nil, nil, nil) == SQLITE_OK else {
            throw LogbookError.query(String(cString: sqlite3_errmsg(database)))
        }
        let sql = "SELECT id, datetime, callsign, band, qrg, mode, rsttx, rstrx, qsl, lotwqsl, eqsl, dxcc, cq, itu, cnt, note, locator, dxccadif FROM logbook ORDER BY datetime DESC, id DESC"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw LogbookError.query(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(statement) }

        var byCall: [String: [QSORecord]] = [:]
        var callBands: [String: Set<String>] = [:], callModes: [String: Set<String>] = [:]
        var confirmedCallBandModes = Set<String>(), dxccBands: [Int: Set<String>] = [:], dxccModes: [Int: Set<String>] = [:]
        var workedDXCC = Set<Int>(), confirmedDXCC = Set<Int>(), confirmedDXCCBandModes = Set<String>()
        var count = 0
        while sqlite3_step(statement) == SQLITE_ROW {
            let call = text(statement, 2).removingPercentEncoding?.uppercased() ?? text(statement, 2).uppercased()
            let band = text(statement, 3).lowercased(), mode = SpotLogic.normalizedMode(text(statement, 5))
            let date = parseDate(text(statement, 1))
            let record = QSORecord(id: sqlite3_column_int64(statement, 0), date: date, callsign: call, band: band,
                                   frequencyKHz: Double(text(statement, 4).replacingOccurrences(of: ",", with: ".")) ?? 0,
                                   mode: mode, rstSent: text(statement, 6), rstReceived: text(statement, 7),
                                   paperQSL: text(statement, 8), lotwQSL: text(statement, 9), eqsl: text(statement, 10),
                                   countryPrefix: text(statement, 11), cqZone: text(statement, 12), ituZone: text(statement, 13),
                                   continent: text(statement, 14).uppercased(), note: text(statement, 15).removingPercentEncoding ?? text(statement, 15),
                                   grid: text(statement, 16).uppercased(), adif: Int(sqlite3_column_int(statement, 17)))
            byCall[call, default: []].append(record)
            callBands[call, default: []].insert(band)
            callModes[call, default: []].insert(mode)
            if record.isConfirmed { confirmedCallBandModes.insert(key(call, band, mode)) }
            if record.adif > 0 {
                workedDXCC.insert(record.adif); dxccBands[record.adif, default: []].insert(band); dxccModes[record.adif, default: []].insert(mode)
                if record.isConfirmed { confirmedDXCC.insert(record.adif); confirmedDXCCBandModes.insert(key(String(record.adif), band, mode)) }
            }
            count += 1
        }
        guard sqlite3_errcode(database) == SQLITE_OK || sqlite3_errcode(database) == SQLITE_DONE else {
            throw LogbookError.query(String(cString: sqlite3_errmsg(database)))
        }
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return LogbookIndex(loadedAt: Date(), modifiedAt: attributes?[.modificationDate] as? Date, recordCount: count,
                            recordsByCall: byCall, callBands: callBands, callModes: callModes,
                            confirmedCallBandModes: confirmedCallBandModes, dxccBands: dxccBands, dxccModes: dxccModes,
                            workedDXCC: workedDXCC, confirmedDXCC: confirmedDXCC, confirmedDXCCBandModes: confirmedDXCCBandModes)
    }

    public func classify(call: String, band: String, mode: String, adif: Int?) -> (String, String, Date?) {
        let normalizedCall = call.uppercased(), normalizedBand = band.lowercased(), normalizedMode = SpotLogic.normalizedMode(mode)
        let histories = recordsByCall[normalizedCall] ?? []
        let callStatus = SpotLogic.callStatus(
            worked: !histories.isEmpty,
            newBand: !(callBands[normalizedCall]?.contains(normalizedBand) ?? false),
            newMode: !(callModes[normalizedCall]?.contains(normalizedMode) ?? false),
            confirmedBandMode: confirmedCallBandModes.contains(Self.key(normalizedCall, normalizedBand, normalizedMode))
        )
        guard let adif, adif > 0 else { return (callStatus, "Unknown", histories.first?.date) }
        let dxccStatus = SpotLogic.dxccStatus(
            worked: workedDXCC.contains(adif), confirmed: confirmedDXCC.contains(adif),
            newBand: !(dxccBands[adif]?.contains(normalizedBand) ?? false),
            newMode: !(dxccModes[adif]?.contains(normalizedMode) ?? false),
            confirmedBandMode: confirmedDXCCBandModes.contains(Self.key(String(adif), normalizedBand, normalizedMode))
        )
        let exact = histories.first(where: { $0.band == normalizedBand && $0.mode == normalizedMode })?.date
        return (callStatus, dxccStatus, exact)
    }

    public func history(call: String, country: CountryInfo?) -> HistorySummary {
        let records = recordsByCall[call.uppercased()] ?? []
        return HistorySummary(records: records, country: country, grid: records.first(where: { !$0.grid.isEmpty })?.grid ?? "")
    }

    private static func key(_ first: String, _ band: String, _ mode: String) -> String { "\(first)|\(band.lowercased())|\(SpotLogic.normalizedMode(mode))" }
}

private func text(_ statement: OpaquePointer, _ column: Int32) -> String {
    guard let value = sqlite3_column_text(statement, column) else { return "" }
    return String(cString: value)
}

private func parseDate(_ value: String) -> Date {
    let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return formatter.date(from: value) ?? .distantPast
}

private func key(_ first: String, _ band: String, _ mode: String) -> String { "\(first)|\(band.lowercased())|\(SpotLogic.normalizedMode(mode))" }
