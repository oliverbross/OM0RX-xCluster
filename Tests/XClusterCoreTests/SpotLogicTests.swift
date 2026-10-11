import XCTest
@testable import XClusterCore

final class SpotLogicTests: XCTestCase {
    func testClusterLineParsingPreservesFrequencyAndComment() throws {
        let raw = try XCTUnwrap(ClusterLineParser.parse("DX de K3KS: 28460.0 KC3JAS PA QSO PARTY-CLE", clusterID: UUID(), clusterName: "test"))
        XCTAssertEqual(raw.callsign, "KC3JAS")
        XCTAssertEqual(raw.frequencyKHz, 28460.0)
        XCTAssertEqual(raw.comment, "PA QSO PARTY-CLE")
    }

    func testClusterLineParsingRemovesOnlyTrailingUTCTime() throws {
        let timestamped = try XCTUnwrap(ClusterLineParser.parse("DX de W2LCQ: 3869.0 N3NTJ PA QSO Party: Mercer 0003Z", clusterID: UUID(), clusterName: "test"))
        XCTAssertEqual(timestamped.comment, "PA QSO Party: Mercer")

        let timestampOnly = try XCTUnwrap(ClusterLineParser.parse("DX de K3KS: 28460.0 KC3JAS 2359Z", clusterID: UUID(), clusterName: "test"))
        XCTAssertEqual(timestampOnly.comment, "")

        let meaningfulNumber = try XCTUnwrap(ClusterLineParser.parse("DX de K3KS: 28460.0 KC3JAS POTA K-0003Z", clusterID: UUID(), clusterName: "test"))
        XCTAssertEqual(meaningfulNumber.comment, "POTA K-0003Z")
    }

    func testDXSpiderHistoryLineLoadsAsSpotWithOriginalTime() throws {
        let clusterID = UUID()
        let raw = try XCTUnwrap(ClusterLineParser.parse(
            "7150.0 AD4PF       11-Oct-2026 0018Z CQ Dx 59 in FJ24en           <HJ6AZV>",
            clusterID: clusterID,
            clusterName: "ShackCQ"
        ))
        XCTAssertEqual(raw.clusterID, clusterID)
        XCTAssertEqual(raw.frequencyKHz, 7150.0)
        XCTAssertEqual(raw.callsign, "AD4PF")
        XCTAssertEqual(raw.spotter, "HJ6AZV")
        XCTAssertEqual(raw.comment, "CQ Dx 59 in FJ24en")

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day, .hour, .minute], from: raw.receivedAt),
                       DateComponents(year: 2026, month: 10, day: 11, hour: 0, minute: 18))
    }

    func testDXSpiderHistoryLineAllowsBlankComment() throws {
        let raw = try XCTUnwrap(ClusterLineParser.parse(
            "3830.0 N3ZK        11-Oct-2026 0017Z                                <NF3R>",
            clusterID: UUID(),
            clusterName: "ShackCQ"
        ))
        XCTAssertEqual(raw.callsign, "N3ZK")
        XCTAssertEqual(raw.spotter, "NF3R")
        XCTAssertEqual(raw.comment, "")
    }

    func testDXSpiderHistoryLineAllowsAdjacentSpotterMarker() throws {
        let raw = try XCTUnwrap(ClusterLineParser.parse(
            "14247.5 K3RWN/ALL   11-Oct-2026 0013Z Heard in EL87 73s W4MBM via PO<W4MBM>",
            clusterID: UUID(),
            clusterName: "ShackCQ"
        ))
        XCTAssertEqual(raw.callsign, "K3RWN/ALL")
        XCTAssertEqual(raw.spotter, "W4MBM")
        XCTAssertEqual(raw.comment, "Heard in EL87 73s W4MBM via PO")
    }

    func testBandModeAndSourceInferenceMatchOM0RXRules() {
        XCTAssertEqual(SpotLogic.band(for: 14074), "20m")
        XCTAssertEqual(SpotLogic.mode(comment: "TNX FT8", band: "20m", khz: 14074), "FT8")
        XCTAssertEqual(SpotLogic.mode(comment: "", band: "40m", khz: 7025), "CW")
        XCTAssertEqual(SpotLogic.source(spotter: "DL1ABC-#", comment: "CW 18 dB"), "rbl")
        XCTAssertEqual(SpotLogic.source(spotter: "DL1ABC/#", comment: "FT8 -12 dB"), "rbl")
        let rbn = ClusterLineParser.parse("DX de DL1ABC-#: 14027.0 OM0RX 23 dB 28 WPM CQ 1234Z", clusterID: UUID(), clusterName: "test")
        XCTAssertEqual(rbn.map { SpotLogic.source(spotter: $0.spotter, comment: $0.comment) }, "rbl")
        XCTAssertEqual(rbn?.comment, "23 dB 28 WPM CQ")
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

    func testWorkedBandModeVisibilityDefaultsToHidden() {
        XCTAssertFalse(SpotLogic.shouldShow(callStatus: "Worked", showWorkedBandModeSpots: false))
        XCTAssertFalse(SpotLogic.shouldShow(callStatus: "Confirmed", showWorkedBandModeSpots: false))
        XCTAssertTrue(SpotLogic.shouldShow(callStatus: "New Mode", showWorkedBandModeSpots: false))
        XCTAssertTrue(SpotLogic.shouldShow(callStatus: "New Band", showWorkedBandModeSpots: false))
        XCTAssertTrue(SpotLogic.shouldShow(callStatus: "Worked", showWorkedBandModeSpots: true))
    }

    func testLegacySettingsEnableSkimmerAndHideWorkedCombinations() throws {
        let legacy = #"{"clusters":[],"logbookPath":"","maximumSpots":200,"reconnect":true,"statusPalette":{"colors":{}},"specialRules":[]}"#.data(using: .utf8)!
        let settings = try JSONDecoder().decode(AppSettings.self, from: legacy)
        XCTAssertTrue(settings.requestSkimmerSpots)
        XCTAssertFalse(settings.showWorkedBandModeSpots)
        XCTAssertTrue(settings.transferSpotNoteToRUMlog)
        XCTAssertEqual(settings.spotHandoffTarget, .xLog)
        XCTAssertTrue(settings.rigCtlModeEnabled)
        XCTAssertEqual(settings.rigCtlHost, "127.0.0.1")
        XCTAssertEqual(settings.rigCtlPort, 14532)
        XCTAssertEqual(settings.bandPalette, .bandDefaults)
        XCTAssertEqual(settings.modePalette, .modeDefaults)
    }

    func testRUMlogNoteEscapesAppleScriptMetacharactersAndControls() {
        XCTAssertEqual(RUMlogController.appleScriptString("CQ \"DX\"\\path\nnext\tline"), "CQ \\\"DX\\\"\\\\path next line")
    }

    func testXLogSpotURLCarriesFrequencyModeAndNote() throws {
        let url = try XLogController().url(callsign: "RG1L/MM", frequencyKHz: 14_006.5, mode: "CW", note: nil, referenceText: "POTA K-1234", specialTags: ["POTA"])
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let values = Dictionary(uniqueKeysWithValues: components.queryItems?.compactMap { item in item.value.map { (item.name, $0) } } ?? [])
        XCTAssertEqual(components.scheme, "om0rx-xlog")
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "special" })?.value, "POTA")
        XCTAssertEqual(values["call"], "RG1L/MM")
        XCTAssertEqual(values["frequency"], "14006.500")
        XCTAssertEqual(values["mode"], "CW")
        XCTAssertNil(values["comment"])
        XCTAssertEqual(values["references"], "POTA K-1234")
    }

    func testSpotModesMapToRadioModes() {
        XCTAssertEqual(RigCtlModeController.radioMode(for: "SSB", frequencyKHz: 7_125), "LSB")
        XCTAssertEqual(RigCtlModeController.radioMode(for: "SSB", frequencyKHz: 14_250), "USB")
        XCTAssertEqual(RigCtlModeController.radioMode(for: "FT8", frequencyKHz: 14_074), "DIGU")
        XCTAssertEqual(RigCtlModeController.radioMode(for: "FT4", frequencyKHz: 7_047.5), "DIGU")
        XCTAssertEqual(RigCtlModeController.radioMode(for: "CW", frequencyKHz: 7_025), "CW")
        XCTAssertEqual(RigCtlModeController.radioMode(for: "RTTY", frequencyKHz: 14_080), "RTTY")
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
