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

public enum SpecialReferenceFormat: String, Codable, CaseIterable, Identifiable, Sendable {
    case none, pota, sota, iota, wwff, bunker, castle

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .none: return "None — words only"
        case .pota: return "POTA — K-1234"
        case .sota: return "SOTA — VK1/AC-001"
        case .iota: return "IOTA — OC-001"
        case .wwff: return "WWFF — VKFF-0123"
        case .bunker: return "Bunkers — B/G-1234"
        case .castle: return "Castles — WCA references"
        }
    }

    var pattern: String? {
        switch self {
        case .none: return nil
        case .pota: return #"\b(?:[A-Z]{1,3})-\d{4,5}\b"#
        case .sota: return #"\b[A-Z0-9]{1,3}/[A-Z]{1,3}-\d{3}\b"#
        case .iota: return #"\b(?:EU|NA|SA|AS|AF|OC|AN)-\d{3}\b"#
        case .wwff: return #"\b[A-Z0-9]{1,4}FF-\d{3,5}\b"#
        case .bunker: return #"\bB/[A-Z0-9]{1,4}-\d{4}\b"#
        case .castle: return #"\b[A-Z]{1,3}-\d{5}\b"#
        }
    }
}

public struct SpecialRule: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var keywords: [String]
    public var referenceFormat: SpecialReferenceFormat
    public var advancedPattern: String
    public var enabled: Bool

    public init(id: UUID = UUID(), name: String, keywords: [String], referenceFormat: SpecialReferenceFormat = .none,
                advancedPattern: String = "", enabled: Bool = true) {
        self.id = id
        self.name = name
        self.keywords = keywords
        self.referenceFormat = referenceFormat
        self.advancedPattern = advancedPattern
        self.enabled = enabled
    }

    /// Backwards-compatible initializer for imported expert rules.
    public init(id: UUID = UUID(), name: String, pattern: String, enabled: Bool = true) {
        self.init(id: id, name: name, keywords: [], advancedPattern: pattern, enabled: enabled)
    }

    private enum CodingKeys: String, CodingKey { case id, name, keywords, referenceFormat, advancedPattern, pattern, enabled }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try values.decodeIfPresent(String.self, forKey: .name) ?? "SPECIAL"
        enabled = try values.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        if let savedKeywords = try values.decodeIfPresent([String].self, forKey: .keywords) {
            keywords = savedKeywords
            referenceFormat = try values.decodeIfPresent(SpecialReferenceFormat.self, forKey: .referenceFormat) ?? .none
            advancedPattern = try values.decodeIfPresent(String.self, forKey: .advancedPattern) ?? ""
        } else if let migrated = Self.friendlyDefaults(for: name) {
            keywords = migrated.0
            referenceFormat = migrated.1
            advancedPattern = ""
        } else {
            keywords = [name]
            referenceFormat = .none
            advancedPattern = try values.decodeIfPresent(String.self, forKey: .pattern) ?? ""
        }
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(name, forKey: .name)
        try values.encode(keywords, forKey: .keywords)
        try values.encode(referenceFormat, forKey: .referenceFormat)
        try values.encode(advancedPattern, forKey: .advancedPattern)
        try values.encode(enabled, forKey: .enabled)
    }

    private static func friendlyDefaults(for name: String) -> ([String], SpecialReferenceFormat)? {
        switch name.uppercased() {
        case "POTA": return (["POTA"], .pota)
        case "SOTA": return (["SOTA"], .sota)
        case "IOTA": return (["IOTA"], .iota)
        case "WWFF": return (["WWFF"], .wwff)
        case "BUNKER": return (["WWBOTA", "UKBOTA", "BUNKER ON THE AIR", "BUNKERS ON THE AIR"], .bunker)
        case "CASTLE": return (["WCA", "CASTLE"], .castle)
        case "LIGHTHOUSE": return (["LIGHTHOUSE", "ARLHS", "ILLW"], .none)
        case "CONTEST": return (["CONTEST"], .none)
        case "IARU": return (["IARU"], .none)
        default: return nil
        }
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

    public static let bandDefaults = StatusPalette(colors: [
        "160m": "#B794F4", "80m": "#A78BFA", "60m": "#818CF8",
        "40m": "#4A9EFF", "30m": "#22D3EE", "20m": "#12D6A0",
        "17m": "#4ADE80", "15m": "#F3B23C", "12m": "#FB923C",
        "10m": "#FF6B5E", "6m": "#F472B6", "2m": "#E879F9",
        "70cm": "#C084FC", "Unknown": "#B0B0B0",
    ])

    public static let modeDefaults = StatusPalette(colors: [
        "CW": "#F3B23C", "SSB": "#35C8F5", "AM": "#FFD166",
        "FM": "#4A9EFF", "RTTY": "#FB923C", "FT8": "#A78BFA",
        "FT4": "#F472B6", "FT2": "#E879F9", "PSK": "#4ADE80",
        "OLIVIA": "#2DD4BF", "JT65": "#818CF8", "JT9": "#60A5FA",
        "HELL": "#F59E0B", "MFSK": "#34D399", "SSTV": "#F87171",
        "DIGI": "#8B9CFF", "Unknown": "#B0B0B0",
    ])
}

public enum SpotHandoffTarget: String, Codable, CaseIterable, Identifiable, Sendable {
    case xLog = "OM0RX-xLog"
    case rumlog = "RUMlogNG"
    public var id: String { rawValue }
}

public enum LogbookSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case xLog = "OM0RX-xLog"
    case rumlog = "RUMlogNG"
    public var id: String { rawValue }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var clusters: [ClusterServer]
    public var logbookPath: String
    public var logbookSource: LogbookSource
    public var maximumSpots: Int
    public var reconnect: Bool
    public var requestSkimmerSpots: Bool
    public var showWorkedBandModeSpots: Bool
    public var transferSpotNoteToRUMlog: Bool
    public var spotHandoffTarget: SpotHandoffTarget
    public var rigCtlModeEnabled: Bool
    public var rigCtlHost: String
    public var rigCtlPort: Int
    public var statusPalette: StatusPalette
    public var bandPalette: StatusPalette
    public var modePalette: StatusPalette
    public var specialRules: [SpecialRule]

    public static let defaults = AppSettings(
        clusters: [ClusterServer(name: "ShackCQ", host: "cluster.shackcq.com", port: 7300, callsign: "OM0RX-12")],
        logbookPath: "",
        logbookSource: .xLog,
        maximumSpots: 200,
        reconnect: true,
        requestSkimmerSpots: true,
        showWorkedBandModeSpots: false,
        transferSpotNoteToRUMlog: true,
        spotHandoffTarget: .xLog,
        rigCtlModeEnabled: true,
        rigCtlHost: "127.0.0.1",
        rigCtlPort: 14532,
        statusPalette: .defaults,
        bandPalette: .bandDefaults,
        modePalette: .modeDefaults,
        specialRules: [
            SpecialRule(name: "POTA", keywords: ["POTA"], referenceFormat: .pota),
            SpecialRule(name: "SOTA", keywords: ["SOTA"], referenceFormat: .sota),
            SpecialRule(name: "IOTA", keywords: ["IOTA"], referenceFormat: .iota),
            SpecialRule(name: "WWFF", keywords: ["WWFF"], referenceFormat: .wwff),
            SpecialRule(name: "BUNKER", keywords: ["WWBOTA", "UKBOTA", "BUNKER ON THE AIR", "BUNKERS ON THE AIR"], referenceFormat: .bunker),
            SpecialRule(name: "CASTLE", keywords: ["WCA", "CASTLE"], referenceFormat: .castle),
            SpecialRule(name: "LIGHTHOUSE", keywords: ["LIGHTHOUSE", "ARLHS", "ILLW"]),
            SpecialRule(name: "CONTEST", keywords: ["CONTEST"]),
            SpecialRule(name: "IARU", keywords: ["IARU"]),
        ]
    )

    private enum CodingKeys: String, CodingKey {
        case clusters, logbookPath, logbookSource, maximumSpots, reconnect, requestSkimmerSpots, showWorkedBandModeSpots, transferSpotNoteToRUMlog, spotHandoffTarget
        case rigCtlModeEnabled, rigCtlHost, rigCtlPort, statusPalette, bandPalette, modePalette, specialRules
    }

    public init(clusters: [ClusterServer], logbookPath: String, logbookSource: LogbookSource = .xLog, maximumSpots: Int, reconnect: Bool,
                requestSkimmerSpots: Bool, showWorkedBandModeSpots: Bool,
                transferSpotNoteToRUMlog: Bool, spotHandoffTarget: SpotHandoffTarget = .xLog,
                rigCtlModeEnabled: Bool, rigCtlHost: String, rigCtlPort: Int,
                statusPalette: StatusPalette, bandPalette: StatusPalette, modePalette: StatusPalette,
                specialRules: [SpecialRule]) {
        self.clusters = clusters
        self.logbookPath = logbookPath
        self.logbookSource = logbookSource
        self.maximumSpots = maximumSpots
        self.reconnect = reconnect
        self.requestSkimmerSpots = requestSkimmerSpots
        self.showWorkedBandModeSpots = showWorkedBandModeSpots
        self.transferSpotNoteToRUMlog = transferSpotNoteToRUMlog
        self.spotHandoffTarget = spotHandoffTarget
        self.rigCtlModeEnabled = rigCtlModeEnabled
        self.rigCtlHost = rigCtlHost
        self.rigCtlPort = rigCtlPort
        self.statusPalette = statusPalette
        self.bandPalette = bandPalette
        self.modePalette = modePalette
        self.specialRules = specialRules
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self.defaults
        clusters = try values.decodeIfPresent([ClusterServer].self, forKey: .clusters) ?? defaults.clusters
        logbookPath = try values.decodeIfPresent(String.self, forKey: .logbookPath) ?? defaults.logbookPath
        logbookSource = try values.decodeIfPresent(LogbookSource.self, forKey: .logbookSource) ?? .xLog
        maximumSpots = try values.decodeIfPresent(Int.self, forKey: .maximumSpots) ?? defaults.maximumSpots
        reconnect = try values.decodeIfPresent(Bool.self, forKey: .reconnect) ?? defaults.reconnect
        requestSkimmerSpots = try values.decodeIfPresent(Bool.self, forKey: .requestSkimmerSpots) ?? true
        showWorkedBandModeSpots = try values.decodeIfPresent(Bool.self, forKey: .showWorkedBandModeSpots) ?? false
        transferSpotNoteToRUMlog = try values.decodeIfPresent(Bool.self, forKey: .transferSpotNoteToRUMlog) ?? true
        spotHandoffTarget = try values.decodeIfPresent(SpotHandoffTarget.self, forKey: .spotHandoffTarget) ?? .xLog
        rigCtlModeEnabled = try values.decodeIfPresent(Bool.self, forKey: .rigCtlModeEnabled) ?? true
        rigCtlHost = try values.decodeIfPresent(String.self, forKey: .rigCtlHost) ?? "127.0.0.1"
        rigCtlPort = try values.decodeIfPresent(Int.self, forKey: .rigCtlPort) ?? 14532
        statusPalette = try values.decodeIfPresent(StatusPalette.self, forKey: .statusPalette) ?? defaults.statusPalette
        bandPalette = try values.decodeIfPresent(StatusPalette.self, forKey: .bandPalette) ?? defaults.bandPalette
        modePalette = try values.decodeIfPresent(StatusPalette.self, forKey: .modePalette) ?? defaults.modePalette
        specialRules = try values.decodeIfPresent([SpecialRule].self, forKey: .specialRules) ?? defaults.specialRules
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(clusters, forKey: .clusters)
        try values.encode(logbookPath, forKey: .logbookPath)
        try values.encode(logbookSource, forKey: .logbookSource)
        try values.encode(maximumSpots, forKey: .maximumSpots)
        try values.encode(reconnect, forKey: .reconnect)
        try values.encode(requestSkimmerSpots, forKey: .requestSkimmerSpots)
        try values.encode(showWorkedBandModeSpots, forKey: .showWorkedBandModeSpots)
        try values.encode(transferSpotNoteToRUMlog, forKey: .transferSpotNoteToRUMlog)
        try values.encode(spotHandoffTarget, forKey: .spotHandoffTarget)
        try values.encode(rigCtlModeEnabled, forKey: .rigCtlModeEnabled)
        try values.encode(rigCtlHost, forKey: .rigCtlHost)
        try values.encode(rigCtlPort, forKey: .rigCtlPort)
        try values.encode(statusPalette, forKey: .statusPalette)
        try values.encode(bandPalette, forKey: .bandPalette)
        try values.encode(modePalette, forKey: .modePalette)
        try values.encode(specialRules, forKey: .specialRules)
    }
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
    public var dxccRecords: [QSORecord]
    public var country: CountryInfo?
    public var grid: String
}

public enum ConnectionState: String, Sendable {
    case disconnected, connecting, connected, failed
}
