import Foundation
import XCTest
@testable import XClusterCore

final class SpotSnapshotTests: XCTestCase {
    func testSnapshotRoundTripPreservesClassificationAndColours() throws {
        let raw = RawSpot(clusterID: UUID(), clusterName: "Test", spotter: "OM0RX", frequencyKHz: 14_074,
                          frequencyText: "14074.0", callsign: "VK4JAZ", comment: "POTA", receivedAt: Date())
        let country = CountryInfo(name: "Australia", adif: 150, continent: "OC", cqZone: 30, ituZone: 55, latitude: -25, longitude: 135)
        let spot = DXSpot(raw: raw, band: "20m", mode: "FT8", country: country, callStatus: "New Band",
                          dxccStatus: "C/New Band", specialTags: ["POTA"], workedBefore: nil, score: 56,
                          scoreReasons: ["C/New Band", "POTA"], source: "cluster")
        let shared = SharedClusterSpot(spot: spot, settings: .defaults)
        let snapshot = SharedSpotSnapshot(connectedClusters: 1, spots: [shared])
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }

        try SpotSnapshotStore.write(snapshot, to: url)
        let decoded = try SpotSnapshotStore.read(from: url)

        XCTAssertEqual(decoded.spots.first?.callsign, "VK4JAZ")
        XCTAssertEqual(decoded.spots.first?.statusHex, AppSettings.defaults.statusPalette.colors["New Band"])
        XCTAssertEqual(decoded.spots.first?.latitude, -25)
    }
}
