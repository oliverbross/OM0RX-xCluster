import Foundation
import SQLite3

public enum LogbookError: Error, LocalizedError {
    case missing(String), open(String), query(String)
    public var errorDescription: String? {
        switch self {
        case .missing(let path): return "Logbook not found at \(path)."
        case .open(let message): return "Could not open the logbook read-only: \(message)"
        case .query(let message): return "Could not read the logbook: \(message)"
        }
    }
}

public struct LogbookIndex: Sendable {
    public let loadedAt: Date
    public let modifiedAt: Date?
    public let recordCount: Int
    private let recordsByCall: [String: [QSORecord]]
    private let recordsByADIF: [Int: [QSORecord]]
    private let callBands: [String: Set<String>]
    private let callModes: [String: Set<String>]
    private let workedCallBandModes: Set<String>
    private let confirmedCallBandModes: Set<String>
    private let dxccBands: [Int: Set<String>]
    private let dxccModes: [Int: Set<String>]
    private let workedDXCC: Set<Int>
    private let confirmedDXCC: Set<Int>
    private let confirmedDXCCBandModes: Set<String>

    public static let empty = LogbookIndex(loadedAt: .distantPast, modifiedAt: nil, recordCount: 0, recordsByCall: [:], recordsByADIF: [:], callBands: [:], callModes: [:], workedCallBandModes: [], confirmedCallBandModes: [], dxccBands: [:], dxccModes: [:], workedDXCC: [], confirmedDXCC: [], confirmedDXCCBandModes: [])

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
        let records = try hasTable(database, name: "qsos")
            ? loadXLogRecords(database)
            : loadRUMlogRecords(database)
        return build(records: records, url: url)
    }

    private static func loadRUMlogRecords(_ database: OpaquePointer) throws -> [QSORecord] {
        let sql = "SELECT id, datetime, callsign, band, qrg, mode, rsttx, rstrx, qsl, lotwqsl, eqsl, dxcc, cq, itu, cnt, note, locator, dxccadif FROM logbook ORDER BY datetime DESC, id DESC"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw LogbookError.query(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(statement) }
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        var records: [QSORecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let rawCall = text(statement, 2).removingPercentEncoding ?? text(statement, 2)
            let call = rawCall.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let band = text(statement, 3).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let mode = SpotLogic.normalizedMode(text(statement, 5))
            let date = dateFormatter.date(from: text(statement, 1)) ?? .distantPast
            let record = QSORecord(id: sqlite3_column_int64(statement, 0), date: date, callsign: call, band: band,
                                   frequencyKHz: Double(text(statement, 4).replacingOccurrences(of: ",", with: ".")) ?? 0,
                                   mode: mode, rstSent: text(statement, 6), rstReceived: text(statement, 7),
                                   paperQSL: text(statement, 8), lotwQSL: text(statement, 9), eqsl: text(statement, 10),
                                   countryPrefix: text(statement, 11), cqZone: text(statement, 12), ituZone: text(statement, 13),
                                   continent: text(statement, 14).uppercased(), note: text(statement, 15).removingPercentEncoding ?? text(statement, 15),
                                   grid: text(statement, 16).uppercased(), adif: Int(sqlite3_column_int(statement, 17)))
            records.append(record)
        }
        guard sqlite3_errcode(database) == SQLITE_OK || sqlite3_errcode(database) == SQLITE_DONE else {
            throw LogbookError.query(String(cString: sqlite3_errmsg(database)))
        }
        return records
    }

    private struct XLogStoredQSO: Decodable {
        var call: String
        var start: Date
        var band: String
        var mode: String
        var submode: String
        var frequencyHz: Int64?
        var rstSent: String
        var rstReceived: String
        var gridSquare: String
        var country: String
        var dxcc: Int?
        var continent: String
        var cqZone: String
        var ituZone: String
        var comment: String
        var notes: String
        var qslReceived: String
        var lotwReceived: String
    }

    private static func loadXLogRecords(_ database: OpaquePointer) throws -> [QSORecord] {
        var statement: OpaquePointer?
        let sql = "SELECT rowid, record_json FROM qsos WHERE deleted_at IS NULL ORDER BY qso_start DESC"
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw LogbookError.query(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(statement) }
        let decoder = JSONDecoder()
        let resolver = try? CTYResolver.bundled()
        var records: [QSORecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let bytes = sqlite3_column_blob(statement, 1) else { continue }
            let data = Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, 1)))
            guard let value = try? decoder.decode(XLogStoredQSO.self, from: data) else { continue }
            let resolvedCountry = resolver?.resolve(value.call)
            records.append(QSORecord(
                id: sqlite3_column_int64(statement, 0),
                date: value.start,
                callsign: value.call.uppercased(),
                band: value.band.lowercased(),
                frequencyKHz: Double(value.frequencyHz ?? 0) / 1_000,
                mode: SpotLogic.normalizedMode(value.submode.isEmpty ? value.mode : value.submode),
                rstSent: value.rstSent,
                rstReceived: value.rstReceived,
                paperQSL: value.qslReceived,
                lotwQSL: value.lotwReceived,
                eqsl: "",
                countryPrefix: value.country.isEmpty ? resolvedCountry?.name ?? "" : value.country,
                cqZone: value.cqZone.isEmpty ? resolvedCountry.map { String($0.cqZone) } ?? "" : value.cqZone,
                ituZone: value.ituZone.isEmpty ? resolvedCountry.map { String($0.ituZone) } ?? "" : value.ituZone,
                continent: value.continent.isEmpty ? resolvedCountry?.continent ?? "" : value.continent.uppercased(),
                note: value.comment.isEmpty ? value.notes : value.comment,
                grid: value.gridSquare.uppercased(),
                adif: value.dxcc ?? resolvedCountry?.adif ?? 0
            ))
        }
        guard sqlite3_errcode(database) == SQLITE_OK || sqlite3_errcode(database) == SQLITE_DONE else {
            throw LogbookError.query(String(cString: sqlite3_errmsg(database)))
        }
        return records
    }

    private static func build(records: [QSORecord], url: URL) -> LogbookIndex {
        var byCall: [String: [QSORecord]] = [:]
        var byADIF: [Int: [QSORecord]] = [:]
        var callBands: [String: Set<String>] = [:], callModes: [String: Set<String>] = [:]
        var workedCallBandModes = Set<String>(), confirmedCallBandModes = Set<String>(), dxccBands: [Int: Set<String>] = [:], dxccModes: [Int: Set<String>] = [:]
        var workedDXCC = Set<Int>(), confirmedDXCC = Set<Int>(), confirmedDXCCBandModes = Set<String>()
        for record in records {
            let call = record.callsign
            byCall[call, default: []].append(record)
            callBands[call, default: []].insert(record.band)
            callModes[call, default: []].insert(record.mode)
            workedCallBandModes.insert(key(call, record.band, record.mode))
            if record.isConfirmed { confirmedCallBandModes.insert(key(call, record.band, record.mode)) }
            if record.adif > 0 {
                byADIF[record.adif, default: []].append(record)
                workedDXCC.insert(record.adif)
                dxccBands[record.adif, default: []].insert(record.band)
                dxccModes[record.adif, default: []].insert(record.mode)
                if record.isConfirmed {
                    confirmedDXCC.insert(record.adif)
                    confirmedDXCCBandModes.insert(key(String(record.adif), record.band, record.mode))
                }
            }
        }
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return LogbookIndex(loadedAt: Date(), modifiedAt: attributes?[.modificationDate] as? Date, recordCount: records.count,
                            recordsByCall: byCall, recordsByADIF: byADIF, callBands: callBands, callModes: callModes,
                            workedCallBandModes: workedCallBandModes, confirmedCallBandModes: confirmedCallBandModes,
                            dxccBands: dxccBands, dxccModes: dxccModes,
                            workedDXCC: workedDXCC, confirmedDXCC: confirmedDXCC, confirmedDXCCBandModes: confirmedDXCCBandModes)
    }

    private static func hasTable(_ database: OpaquePointer, name: String) throws -> Bool {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "SELECT 1 FROM sqlite_master WHERE type='table' AND name=? LIMIT 1", -1, &statement, nil) == SQLITE_OK,
              let statement else { throw LogbookError.query(String(cString: sqlite3_errmsg(database))) }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, name, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        return sqlite3_step(statement) == SQLITE_ROW
    }

    public func classify(call: String, band: String, mode: String, adif: Int?) -> (String, String, Date?) {
        let normalizedCall = call.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let normalizedBand = band.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedMode = SpotLogic.normalizedMode(mode)
        let histories = recordsByCall[normalizedCall] ?? []
        let bandWorked = callBands[normalizedCall]?.contains(normalizedBand) ?? false
        let modeWorked = callModes[normalizedCall]?.contains(normalizedMode) ?? false
        let bandModeKey = Self.key(normalizedCall, normalizedBand, normalizedMode)
        let callStatus = SpotLogic.callStatus(
            worked: !histories.isEmpty,
            bandWorked: bandWorked,
            modeWorked: modeWorked,
            bandModeWorked: workedCallBandModes.contains(bandModeKey),
            confirmedBandMode: confirmedCallBandModes.contains(bandModeKey)
        )
        let workedBefore = Self.workedBeforeDate(records: histories, band: normalizedBand, mode: normalizedMode)
        guard let adif, adif > 0 else { return (callStatus, "Unknown", workedBefore) }
        let dxccStatus = SpotLogic.dxccStatus(
            worked: workedDXCC.contains(adif), confirmed: confirmedDXCC.contains(adif),
            newBand: !(dxccBands[adif]?.contains(normalizedBand) ?? false),
            newMode: !(dxccModes[adif]?.contains(normalizedMode) ?? false),
            confirmedBandMode: confirmedDXCCBandModes.contains(Self.key(String(adif), normalizedBand, normalizedMode))
        )
        return (callStatus, dxccStatus, workedBefore)
    }

    public func history(call: String, country: CountryInfo?) -> HistorySummary {
        let normalizedCall = call.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let records = recordsByCall[normalizedCall] ?? []
        let dxccRecords = country.map { recordsByADIF[$0.adif] ?? [] } ?? []
        return HistorySummary(records: records, dxccRecords: dxccRecords, country: country,
                              grid: records.first(where: { !$0.grid.isEmpty })?.grid ?? "")
    }

    static func workedBeforeDate(records: [QSORecord], band: String, mode: String) -> Date? {
        let normalizedBand = band.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedMode = SpotLogic.normalizedMode(mode)
        return records.first(where: { $0.band == normalizedBand && $0.mode == normalizedMode })?.date
            ?? records.first(where: { $0.band == normalizedBand })?.date
    }

    private static func key(_ first: String, _ band: String, _ mode: String) -> String { "\(first)|\(band.lowercased())|\(SpotLogic.normalizedMode(mode))" }
}

private func text(_ statement: OpaquePointer, _ column: Int32) -> String {
    guard let value = sqlite3_column_text(statement, column) else { return "" }
    return String(cString: value)
}

private func key(_ first: String, _ band: String, _ mode: String) -> String { "\(first)|\(band.lowercased())|\(SpotLogic.normalizedMode(mode))" }
