import Foundation

public struct ClusterServer: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var host: String
    public var port: Int
    public var callsign: String
    public var enabled: Bool

    public init(id: UUID = UUID(), name: String, host: String, port: Int, callsign: String, enabled: Bool = true) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.callsign = callsign
        self.enabled = enabled
    }
}

public struct SpecialRule: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var pattern: String
    public var enabled: Bool

    public init(id: UUID = UUID(), name: String, pattern: String, enabled: Bool = true) {
        self.id = id
        self.name = name
        self.pattern = pattern
        self.enabled = enabled
    }
}

public struct StatusPalette: Codable, Equatable, Sendable {
    public var colors: [String: String]

    public static let defaults = StatusPalette(colors: [
        "New Call": "#FF6B35", "New Band": "#00BFFF", "New Mode": "#FFC000",
        "New Band+Mode": "#E91E63", "ATNO": "#FF8C00", "C/New Band": "#4A9EFF",
        "C/New Mode": "#FFD93D", "C/New Band+Mode": "#9C27B0", "W/New Band": "#00BCD4",
        "W/New Mode": "#FFA726", "W/New Band+Mode": "#FF5722", "Worked": "#B0B0B0",
        "Confirmed": "#10B981", "Unknown": "#777F8C",
    ])
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var clusters: [ClusterServer]
    public var logbookPath: String
    public var maximumSpots: Int
    public var reconnect: Bool
    public var statusPalette: StatusPalette
    public var specialRules: [SpecialRule]

    public static let defaults = AppSettings(
        clusters: [ClusterServer(name: "ShackCQ", host: "cluster.shackcq.com", port: 7300, callsign: "OM0RX-12")],
        logbookPath: "",
        maximumSpots: 200,
        reconnect: true,
        statusPalette: .defaults,
        specialRules: [
            SpecialRule(name: "POTA", pattern: #"\bPOTA\b|\b(?:[A-Z]{1,3})-\d{4,5}\b"#),
            SpecialRule(name: "SOTA", pattern: #"\bSOTA\b|\b[A-Z0-9]{1,3}/[A-Z]{1,3}-\d{3}\b"#),
            SpecialRule(name: "IOTA", pattern: #"\bIOTA\b|\b(?:EU|NA|SA|AS|AF|OC|AN)-\d{3}\b"#),
            SpecialRule(name: "WWFF", pattern: #"\bWWFF\b|\b[A-Z0-9]{1,4}FF-\d{3,5}\b"#),
            SpecialRule(name: "BUNKER", pattern: #"\b(?:WWBOTA|UKBOTA|BUNKERS? ON THE AIR)\b|\bB/[A-Z0-9]{1,4}-\d{4}\b"#),
            SpecialRule(name: "CASTLE", pattern: #"\bWCA\b|\bCASTLE\b|\b[A-Z]{1,3}-\d{5}\b"#),
            SpecialRule(name: "LIGHTHOUSE", pattern: #"\b(?:LIGHTHOUSE|ARLHS|ILLW)\b"#),
            SpecialRule(name: "CONTEST", pattern: #"\bCONTEST\b"#),
            SpecialRule(name: "IARU", pattern: #"\bIARU\b"#),
        ]
    )
}

public struct CountryInfo: Codable, Hashable, Sendable {
    public var name: String
    public var adif: Int
    public var continent: String
    public var cqZone: Int
    public var ituZone: Int
    public var latitude: Double?
    public var longitude: Double?
}

public struct RawSpot: Hashable, Sendable {
    public var clusterID: UUID
    public var clusterName: String
    public var spotter: String
    public var frequencyKHz: Double
    public var frequencyText: String
    public var callsign: String
    public var comment: String
    public var receivedAt: Date
}

public struct DXSpot: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var receivedAt: Date
    public var clusterName: String
    public var spotter: String
    public var frequencyKHz: Double
    public var frequencyText: String
    public var callsign: String
    public var comment: String
    public var band: String
    public var mode: String
    public var country: CountryInfo?
    public var callStatus: String
    public var dxccStatus: String
    public var specialTags: [String]
    public var workedBefore: Date?
    public var score: Int
    public var scoreReasons: [String]
    public var aggregateCount: Int
    public var aggregateSpotters: [String]
    public var source: String

    public init(raw: RawSpot, band: String, mode: String, country: CountryInfo?, callStatus: String,
                dxccStatus: String, specialTags: [String], workedBefore: Date?, score: Int,
                scoreReasons: [String], source: String) {
        id = UUID(); receivedAt = raw.receivedAt; clusterName = raw.clusterName; spotter = raw.spotter
        frequencyKHz = raw.frequencyKHz; frequencyText = raw.frequencyText; callsign = raw.callsign
        comment = raw.comment; self.band = band; self.mode = mode; self.country = country
        self.callStatus = callStatus; self.dxccStatus = dxccStatus; self.specialTags = specialTags
        self.workedBefore = workedBefore; self.score = score; self.scoreReasons = scoreReasons
        aggregateCount = 1; aggregateSpotters = [raw.spotter]; self.source = source
    }
}

public struct QSORecord: Identifiable, Hashable, Sendable {
    public var id: Int64
    public var date: Date
    public var callsign: String
    public var band: String
    public var frequencyKHz: Double
    public var mode: String
    public var rstSent: String
    public var rstReceived: String
    public var paperQSL: String
    public var lotwQSL: String
    public var eqsl: String
    public var countryPrefix: String
    public var cqZone: String
    public var ituZone: String
    public var continent: String
    public var note: String
    public var grid: String
    public var adif: Int

    public var isConfirmed: Bool {
        Self.confirmed(paperQSL) || Self.confirmed(lotwQSL)
    }

    public var lotwSent: Bool { ["S", "X", "Y"].contains(lotwQSL.uppercased()) }
    public var lotwReceived: Bool { ["X", "Y", "C", "CONFIRMED"].contains(lotwQSL.uppercased()) }

    private static func confirmed(_ value: String) -> Bool {
        ["X", "Y", "YES", "TRUE", "1", "C", "CONFIRMED"].contains(value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
    }
}

public struct HistorySummary: Sendable {
    public var records: [QSORecord]
    public var country: CountryInfo?
    public var grid: String
}

public enum ConnectionState: String, Sendable {
    case disconnected, connecting, connected, failed
}
