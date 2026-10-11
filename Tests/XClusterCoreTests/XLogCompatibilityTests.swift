import Foundation
import SQLite3
import XCTest
@testable import XClusterCore

final class XLogCompatibilityTests: XCTestCase {
    func testReadsXLogSQLiteSchemaReadOnly() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("OM0RX-xLog.sqlite")
        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &database), SQLITE_OK)
        defer { sqlite3_close(database) }
        let schema = """
        CREATE TABLE qsos(local_id TEXT PRIMARY KEY, wavelog_id INTEGER, call TEXT, qso_start REAL, band TEXT, mode TEXT,
        frequency_hz INTEGER, is_dirty INTEGER, deleted_at REAL, updated_at REAL, record_json BLOB);
        """
        XCTAssertEqual(sqlite3_exec(database, schema, nil, nil, nil), SQLITE_OK)
        let stored = Stored(
            call: "VK4JAZ", start: Date(timeIntervalSince1970: 1_700_000_000), band: "20m", mode: "SSB",
            submode: "", frequencyHz: 14_302_500, rstSent: "59", rstReceived: "59", gridSquare: "QG62",
            country: "Australia", dxcc: 150, continent: "OC", cqZone: "30", ituZone: "55",
            comment: "test", notes: "", qslReceived: "", lotwReceived: "Y"
        )
        let data = try JSONEncoder().encode(stored)
        var statement: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(database, "INSERT INTO qsos VALUES(?,?,?,?,?,?,?,?,?,?,?)", -1, &statement, nil), SQLITE_OK)
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, UUID().uuidString, -1, nil)
        sqlite3_bind_null(statement, 2)
        sqlite3_bind_text(statement, 3, stored.call, -1, nil)
        sqlite3_bind_double(statement, 4, stored.start.timeIntervalSince1970)
        sqlite3_bind_text(statement, 5, stored.band, -1, nil)
        sqlite3_bind_text(statement, 6, stored.mode, -1, nil)
        sqlite3_bind_int64(statement, 7, stored.frequencyHz)
        sqlite3_bind_int(statement, 8, 0)
        sqlite3_bind_null(statement, 9)
        sqlite3_bind_double(statement, 10, Date().timeIntervalSince1970)
        _ = data.withUnsafeBytes { sqlite3_bind_blob(statement, 11, $0.baseAddress, Int32($0.count), nil) }
        XCTAssertEqual(sqlite3_step(statement), SQLITE_DONE)
        sqlite3_finalize(statement)
        statement = nil
        sqlite3_close(database)
        database = nil

        let index = try LogbookIndex.load(url: url)
        XCTAssertEqual(index.recordCount, 1)
        let status = index.classify(call: "VK4JAZ", band: "20m", mode: "SSB", adif: 150)
        XCTAssertEqual(status.0, "Confirmed")
        XCTAssertEqual(status.1, "Confirmed")
    }

    private struct Stored: Encodable {
        var call: String; var start: Date; var band: String; var mode: String; var submode: String
        var frequencyHz: Int64; var rstSent: String; var rstReceived: String; var gridSquare: String
        var country: String; var dxcc: Int; var continent: String; var cqZone: String; var ituZone: String
        var comment: String; var notes: String; var qslReceived: String; var lotwReceived: String
    }
}
