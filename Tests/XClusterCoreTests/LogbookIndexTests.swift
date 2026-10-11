import Foundation
import SQLite3
import XCTest
@testable import XClusterCore

final class LogbookIndexTests: XCTestCase {
    func testNF3RPatternIsNewModeWithSameBandWorkedDate() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("xcluster-\(UUID().uuidString).rlog")
        defer { try? FileManager.default.removeItem(at: url) }

        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &database), SQLITE_OK)
        guard let database else { return XCTFail("Could not create fixture database") }
        let sql = """
        CREATE TABLE logbook (
            id INTEGER PRIMARY KEY, datetime TEXT, callsign TEXT, band TEXT, qrg TEXT, mode TEXT,
            rsttx TEXT, rstrx TEXT, qsl TEXT, lotwqsl TEXT, eqsl TEXT, dxcc TEXT, cq TEXT, itu TEXT,
            cnt TEXT, note TEXT, locator TEXT, dxccadif INTEGER
        );
        INSERT INTO logbook VALUES
            (1, '2024-09-25 13:39:45', 'NF3R', '20m', '14075.6', 'FT8', '-10', '-08', 'W', 'X', '', 'K', '5', '8', 'NA', '', '', 291),
            (2, '2024-10-26 16:07:16', 'NF3R', '10m', '28918.2', 'SSB', '59', '59', 'W', 'X', '', 'K', '5', '8', 'NA', '', '', 291);
        """
        XCTAssertEqual(sqlite3_exec(database, sql, nil, nil, nil), SQLITE_OK)
        sqlite3_close(database)

        let index = try LogbookIndex.load(url: url)
        let result = index.classify(call: "NF3R", band: "20m", mode: "SSB", adif: 291)
        XCTAssertEqual(result.0, "New Mode")
        XCTAssertEqual(result.2, utcDate("2024-09-25 13:39:45"))

        let unresolvedDXCC = index.classify(call: "NF3R", band: "20m", mode: "SSB", adif: nil)
        XCTAssertEqual(unresolvedDXCC.0, "New Mode")
        XCTAssertEqual(unresolvedDXCC.2, utcDate("2024-09-25 13:39:45"))

        let newBand = index.classify(call: "NF3R", band: "40m", mode: "SSB", adif: 291)
        XCTAssertEqual(newBand.0, "New Band")
        XCTAssertNil(newBand.2)

        let newBandAndMode = index.classify(call: "NF3R", band: "40m", mode: "CW", adif: 291)
        XCTAssertEqual(newBandAndMode.0, "New Band+Mode")
        XCTAssertNil(newBandAndMode.2)

        let confirmed = index.classify(call: "NF3R", band: "10m", mode: "SSB", adif: 291)
        XCTAssertEqual(confirmed.0, "Confirmed")
        XCTAssertEqual(confirmed.2, utcDate("2024-10-26 16:07:16"))
    }

    private func utcDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: value)
    }
}
