import XCTest
@testable import XClusterCore

final class SpotLogicTests: XCTestCase {
    func testClusterLineParsingPreservesFrequencyAndComment() throws {
        let raw = try XCTUnwrap(ClusterLineParser.parse("DX de K3KS: 28460.0 KC3JAS PA QSO PARTY-CLE", clusterID: UUID(), clusterName: "test"))
        XCTAssertEqual(raw.callsign, "KC3JAS")
        XCTAssertEqual(raw.frequencyKHz, 28460.0)
        XCTAssertEqual(raw.comment, "PA QSO PARTY-CLE")
    }

    func testBandModeAndSourceInferenceMatchOM0RXRules() {
        XCTAssertEqual(SpotLogic.band(for: 14074), "20m")
        XCTAssertEqual(SpotLogic.mode(comment: "TNX FT8", band: "20m", khz: 14074), "FT8")
        XCTAssertEqual(SpotLogic.mode(comment: "", band: "40m", khz: 7025), "CW")
        XCTAssertEqual(SpotLogic.source(spotter: "DL1ABC-#", comment: "CW 18 dB"), "rbl")
        XCTAssertEqual(SpotLogic.normalizedMode(" usb "), "SSB")
    }

    func testClassificationPriority() {
        XCTAssertEqual(SpotLogic.callStatus(worked: false, newBand: true, newMode: true, confirmedBandMode: false), "New Call")
        XCTAssertEqual(SpotLogic.callStatus(worked: true, newBand: true, newMode: true, confirmedBandMode: false), "New Band+Mode")
        XCTAssertEqual(SpotLogic.dxccStatus(worked: true, confirmed: true, newBand: true, newMode: false, confirmedBandMode: false), "C/New Band")
    }

    func testCallStatusUsesTheBandModeCombination() {
        XCTAssertEqual(SpotLogic.callStatus(worked: true, bandWorked: true, modeWorked: true, bandModeWorked: false, confirmedBandMode: false), "New Mode")
        XCTAssertEqual(SpotLogic.callStatus(worked: true, bandWorked: false, modeWorked: true, bandModeWorked: false, confirmedBandMode: false), "New Band")
        XCTAssertEqual(SpotLogic.callStatus(worked: true, bandWorked: false, modeWorked: false, bandModeWorked: false, confirmedBandMode: false), "New Band+Mode")
        XCTAssertEqual(SpotLogic.callStatus(worked: true, bandWorked: true, modeWorked: true, bandModeWorked: true, confirmedBandMode: false), "Worked")
        XCTAssertEqual(SpotLogic.callStatus(worked: true, bandWorked: true, modeWorked: true, bandModeWorked: true, confirmedBandMode: true), "Confirmed")
    }

    func testSpecialsCanMultiMatch() {
        let rules = [SpecialRule(name: "POTA", pattern: #"\bPOTA\b"#), SpecialRule(name: "WWFF", pattern: #"\bWWFF\b"#)]
        XCTAssertEqual(SpotLogic.specials(in: "POTA and WWFF", rules: rules), ["POTA", "WWFF"])
    }

    func testFriendlySpecialRulesMatchWordsAndReferenceFormats() {
        let rules = [
            SpecialRule(name: "POTA", keywords: ["Parks on the Air"], referenceFormat: .pota),
            SpecialRule(name: "IOTA", keywords: ["IOTA"], referenceFormat: .iota),
        ]
        XCTAssertEqual(SpotLogic.specials(in: "CQ K-1234 from OC-001", rules: rules), ["POTA", "IOTA"])
        XCTAssertEqual(SpotLogic.specials(in: "Parks on the Air", rules: rules), ["POTA"])
    }

    func testLegacySpecialRuleMigratesToFriendlyDefaults() throws {
        let data = #"{"id":"00000000-0000-0000-0000-000000000001","name":"POTA","pattern":"\\bPOTA\\b","enabled":true}"#.data(using: .utf8)!
        let rule = try JSONDecoder().decode(SpecialRule.self, from: data)
        XCTAssertEqual(rule.keywords, ["POTA"])
        XCTAssertEqual(rule.referenceFormat, .pota)
        XCTAssertEqual(rule.advancedPattern, "")
    }

    func testWorkedBeforeDateFallsBackToSameBandWhenModeDiffers() {
        let date = Date(timeIntervalSince1970: 1_727_284_385)
        let record = QSORecord(id: 1, date: date, callsign: "NF3R", band: "20m", frequencyKHz: 14_075.6,
                               mode: "FT8", rstSent: "-10", rstReceived: "-08", paperQSL: "W", lotwQSL: "X",
                               eqsl: "", countryPrefix: "K", cqZone: "5", ituZone: "8", continent: "NA",
                               note: "", grid: "", adif: 291)
        XCTAssertEqual(LogbookIndex.workedBeforeDate(records: [record], band: "20m", mode: "SSB"), date)
        XCTAssertNil(LogbookIndex.workedBeforeDate(records: [record], band: "40m", mode: "SSB"))
    }

    func testWorkedBeforeDatePrefersTheExactBandMode() {
        let exactDate = Date(timeIntervalSince1970: 1_700_000_000)
        let newerOtherModeDate = Date(timeIntervalSince1970: 1_710_000_000)
        let exact = QSORecord(id: 1, date: exactDate, callsign: "NF3R", band: "20m", frequencyKHz: 14_200,
                              mode: "SSB", rstSent: "59", rstReceived: "59", paperQSL: "", lotwQSL: "W",
                              eqsl: "", countryPrefix: "K", cqZone: "5", ituZone: "8", continent: "NA",
                              note: "", grid: "", adif: 291)
        let otherMode = QSORecord(id: 2, date: newerOtherModeDate, callsign: "NF3R", band: "20m", frequencyKHz: 14_074,
                                  mode: "FT8", rstSent: "-10", rstReceived: "-08", paperQSL: "", lotwQSL: "X",
                                  eqsl: "", countryPrefix: "K", cqZone: "5", ituZone: "8", continent: "NA",
                                  note: "", grid: "", adif: 291)
        XCTAssertEqual(LogbookIndex.workedBeforeDate(records: [otherMode, exact], band: "20m", mode: "SSB"), exactDate)
    }

    func testBundledCountryResolution() throws {
        let resolver = try CTYResolver.bundled()
        let slovakia = try XCTUnwrap(resolver.resolve("OM0AAO"))
        XCTAssertEqual(slovakia.adif, 504)
        XCTAssertEqual(slovakia.continent, "EU")
        XCTAssertEqual(resolver.resolve("VK8RX")?.continent, "OC")
    }
}
