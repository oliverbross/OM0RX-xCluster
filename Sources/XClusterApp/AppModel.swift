import AppKit
import Foundation
import SwiftUI
import XClusterCore

enum SpotSort: String, CaseIterable, Identifiable {
    case newest = "Newest", score = "Score", frequency = "Frequency", callsign = "Callsign"
    var id: String { rawValue }
}

struct SpotFilter {
    var query = ""
    var bands = Set<String>()
    var modes = Set<String>()
    var continents = Set<String>()
    var callStatuses = Set<String>()
    var dxccStatuses = Set<String>()
    var specials = Set<String>()
    var sources: Set<String> = ["cluster", "rbl"]
    var worked = Set<String>()
    var sort: SpotSort = .newest
}

@MainActor
final class AppModel: ObservableObject {
    @Published var settings: AppSettings
    @Published var spots: [DXSpot] = []
    @Published var filter = SpotFilter()
    @Published var selectedSpotID: UUID?
    @Published var historySpot: DXSpot?
    @Published var connectionStates: [UUID: ConnectionState] = [:]
    @Published var connectionErrors: [UUID: String] = [:]
    @Published var logbook = LogbookIndex.empty
    @Published var logbookStatus = "Choose a RUMlog logbook"
    @Published var lastAction = "Ready"
    @Published var isLoadingLogbook = false
    @Published var showingSettings = false

    private let hub = ClusterHub()
    private let resolver: CTYResolver?
    private var refreshTask: Task<Void, Never>?
    private var lastLogbookModification: Date?

    init() {
        settings = SettingsStore.shared.load()
        resolver = try? CTYResolver.bundled()
    }

    var selectedSpot: DXSpot? { spots.first(where: { $0.id == selectedSpotID }) }
    var connectedCount: Int { connectionStates.values.filter { $0 == .connected }.count }

    var filteredSpots: [DXSpot] {
        var result = spots.filter { spot in
            (filter.query.isEmpty || spot.callsign.localizedCaseInsensitiveContains(filter.query) || spot.country?.name.localizedCaseInsensitiveContains(filter.query) == true || spot.comment.localizedCaseInsensitiveContains(filter.query)) &&
            (filter.bands.isEmpty || filter.bands.contains(spot.band)) &&
            (filter.modes.isEmpty || filter.modes.contains(spot.mode)) &&
            (filter.continents.isEmpty || filter.continents.contains(spot.country?.continent ?? "")) &&
            (filter.callStatuses.isEmpty || filter.callStatuses.contains(spot.callStatus)) &&
            (filter.dxccStatuses.isEmpty || filter.dxccStatuses.contains(spot.dxccStatus)) &&
            (filter.specials.isEmpty || !filter.specials.isDisjoint(with: spot.specialTags)) &&
            filter.sources.contains(spot.source) &&
            (filter.worked.isEmpty || filter.worked.contains(spot.workedBefore == nil ? "Not worked" : "Worked before"))
        }
        switch filter.sort {
        case .newest: result.sort { $0.receivedAt > $1.receivedAt }
        case .score: result.sort { $0.score == $1.score ? $0.receivedAt > $1.receivedAt : $0.score > $1.score }
        case .frequency: result.sort { $0.frequencyKHz < $1.frequencyKHz }
        case .callsign: result.sort { $0.callsign < $1.callsign }
        }
        return result
    }

    func start() {
        reconnectClusters()
        reloadLogbook(force: true)
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                self?.reloadLogbook(force: false)
            }
        }
    }

    func reconnectClusters() {
        connectionStates = Dictionary(uniqueKeysWithValues: settings.clusters.map { ($0.id, .disconnected) })
        hub.start(servers: settings.clusters, reconnect: settings.reconnect, onSpot: { [weak self] raw in
            Task { @MainActor in self?.receive(raw) }
        }, onState: { [weak self] id, state, error in
            Task { @MainActor in
                self?.connectionStates[id] = state
                if let error { self?.connectionErrors[id] = error } else if state == .connected { self?.connectionErrors[id] = nil }
            }
        })
    }

    func saveSettings() {
        do { try SettingsStore.shared.save(settings); lastAction = "Settings saved"; reconnectClusters(); reloadLogbook(force: true) }
        catch { lastAction = error.localizedDescription }
    }

    func chooseLogbook() {
        let panel = NSOpenPanel(); panel.title = "Choose the RUMlog logbook"; panel.allowedContentTypes = [.database, .data]; panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { settings.logbookPath = url.path; saveSettings() }
    }

    func reloadLogbook(force: Bool) {
        guard !settings.logbookPath.isEmpty else { logbookStatus = "Choose a RUMlog logbook"; return }
        let url = URL(fileURLWithPath: settings.logbookPath)
        let modified = (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date
        guard force || modified != lastLogbookModification else { return }
        isLoadingLogbook = true; logbookStatus = "Reading \(url.lastPathComponent)…"
        Task { [weak self] in
            let outcome: (LogbookIndex?, String?) = await Task.detached(priority: .utility) {
                do { return (try LogbookIndex.load(url: url), nil) }
                catch { return (nil, error.localizedDescription) }
            }.value
            guard let self else { return }
            if let index = outcome.0 {
                logbook = index; lastLogbookModification = index.modifiedAt
                logbookStatus = "\(index.recordCount.formatted()) contacts · read-only"
            } else {
                logbookStatus = outcome.1 ?? "Could not read the RUMlog logbook."
            }
            isLoadingLogbook = false
        }
    }

    func receive(_ raw: RawSpot) {
        let band = SpotLogic.band(for: raw.frequencyKHz), mode = SpotLogic.mode(comment: raw.comment, band: band, khz: raw.frequencyKHz)
        let country = resolver?.resolve(raw.callsign)
        let status = logbook.classify(call: raw.callsign, band: band, mode: mode, adif: country?.adif)
        let special = SpotLogic.specials(in: raw.comment, rules: settings.specialRules)
        let source = SpotLogic.source(spotter: raw.spotter, comment: raw.comment)
        let scoring = SpotLogic.score(callStatus: status.0, dxccStatus: status.1, specials: special, source: source)
        var spot = DXSpot(raw: raw, band: band, mode: mode, country: country, callStatus: status.0, dxccStatus: status.1,
                          specialTags: special, workedBefore: status.2, score: scoring.0, scoreReasons: scoring.1, source: source)
        if let index = spots.firstIndex(where: { $0.callsign == spot.callsign && abs($0.frequencyKHz - spot.frequencyKHz) <= 0.1 && Date().timeIntervalSince($0.receivedAt) < 180 }) {
            spot.aggregateCount = spots[index].aggregateCount + 1
            spot.aggregateSpotters = Array(Set(spots[index].aggregateSpotters + [spot.spotter])).sorted()
            spots.remove(at: index)
        }
        spots.insert(spot, at: 0)
        if spots.count > max(settings.maximumSpots * 2, 400) { spots.removeLast(spots.count - max(settings.maximumSpots * 2, 400)) }
    }

    func tune(_ spot: DXSpot) {
        do { try RUMlogController().send(callsign: spot.callsign, frequencyKHz: spot.frequencyKHz, mode: spot.mode); lastAction = "Sent \(spot.callsign) · \(String(format: "%.6f", spot.frequencyKHz / 1000)) MHz to RUMlogNG" }
        catch { lastAction = error.localizedDescription; NSSound.beep() }
    }

    func history(for spot: DXSpot) -> HistorySummary { logbook.history(call: spot.callsign, country: spot.country) }
    func clearFilters() { filter = SpotFilter() }

    func color(for status: String) -> Color { Color(hex: settings.statusPalette.colors[status] ?? "#B0B0B0") }
}

extension Color {
    init(hex: String) {
        let text = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let value = UInt64(text, radix: 16) ?? 0xb0b0b0
        self.init(.sRGB, red: Double((value >> 16) & 0xff) / 255, green: Double((value >> 8) & 0xff) / 255, blue: Double(value & 0xff) / 255, opacity: 1)
    }
}
