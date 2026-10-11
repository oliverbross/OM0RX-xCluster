import Foundation

public struct SharedClusterSpot: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var receivedAt: Date
    public var callsign: String
    public var frequencyKHz: Double
    public var band: String
    public var mode: String
    public var country: String
    public var continent: String
    public var latitude: Double?
    public var longitude: Double?
    public var comment: String
    public var callStatus: String
    public var dxccStatus: String
    public var specialTags: [String]
    public var score: Int
    public var source: String
    public var statusHex: String
    public var bandHex: String
    public var modeHex: String

    public init(spot: DXSpot, settings: AppSettings) {
        id = spot.id; receivedAt = spot.receivedAt; callsign = spot.callsign
        frequencyKHz = spot.frequencyKHz; band = spot.band; mode = spot.mode
        country = spot.country?.name ?? "Unknown"; continent = spot.country?.continent ?? ""
        latitude = spot.country?.latitude; longitude = spot.country?.longitude; comment = spot.comment
        callStatus = spot.callStatus; dxccStatus = spot.dxccStatus; specialTags = spot.specialTags
        score = spot.score; source = spot.source
        statusHex = settings.statusPalette.colors[spot.callStatus] ?? "#B0B0B0"
        bandHex = settings.bandPalette.colors[spot.band] ?? settings.bandPalette.colors["Unknown"] ?? "#B0B0B0"
        modeHex = settings.modePalette.colors[spot.mode] ?? settings.modePalette.colors["Unknown"] ?? "#B0B0B0"
    }
}

public struct SharedSpotSnapshot: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var generatedAt: Date
    public var connectedClusters: Int
    public var spots: [SharedClusterSpot]

    public init(generatedAt: Date = Date(), connectedClusters: Int, spots: [SharedClusterSpot]) {
        schemaVersion = 1
        self.generatedAt = generatedAt
        self.connectedClusters = connectedClusters
        self.spots = spots
    }
}

public enum SpotSnapshotStore {
    public static func defaultURL(fileManager: FileManager = .default) throws -> URL {
        let support = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = support.appendingPathComponent("OM0RX-xCluster", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("spots.json")
    }

    public static func write(_ snapshot: SharedSpotSnapshot, to url: URL? = nil) throws {
        let target = try url ?? defaultURL()
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: target, options: .atomic)
    }

    public static func read(from url: URL? = nil) throws -> SharedSpotSnapshot {
        let target = try url ?? defaultURL()
        return try JSONDecoder().decode(SharedSpotSnapshot.self, from: Data(contentsOf: target))
    }
}
