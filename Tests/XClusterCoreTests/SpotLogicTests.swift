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
    }

    func testClassificationPriority() {
        XCTAssertEqual(SpotLogic.callStatus(worked: false, newBand: true, newMode: true, confirmedBandMode: false), "New Call")
        XCTAssertEqual(SpotLogic.callStatus(worked: true, newBand: true, newMode: true, confirmedBandMode: false), "New Band+Mode")
        XCTAssertEqual(SpotLogic.dxccStatus(worked: true, confirmed: true, newBand: true, newMode: false, confirmedBandMode: false), "C/New Band")
    }

    func testSpecialsCanMultiMatch() {
        let rules = [SpecialRule(name: "POTA", pattern: #"\bPOTA\b"#), SpecialRule(name: "WWFF", pattern: #"\bWWFF\b"#)]
        XCTAssertEqual(SpotLogic.specials(in: "POTA and WWFF", rules: rules), ["POTA", "WWFF"])
    }

    func testBundledCountryResolution() throws {
        let resolver = try CTYResolver.bundled()
        let slovakia = try XCTUnwrap(resolver.resolve("OM0AAO"))
        XCTAssertEqual(slovakia.adif, 504)
        XCTAssertEqual(slovakia.continent, "EU")
        XCTAssertEqual(resolver.resolve("VK8RX")?.continent, "OC")
    }
}
