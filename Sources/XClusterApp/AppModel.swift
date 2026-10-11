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

struct ClusterConsoleLine: Identifiable, Sendable {
    let id = UUID()
    let receivedAt: Date
    let source: String
    let text: String
    let isCommand: Bool
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
    @Published var showingClusterCommands = false
    @Published var clusterCommandTarget: UUID?
    @Published var customClusterCommand = ""
    @Published var clusterConsole: [ClusterConsoleLine] = []

    private let hub = ClusterHub()
    private let resolver: CTYResolver?
    private var refreshTask: Task<Void, Never>?
    private var lastLogbookSignature: String?
    private var loadedLogbookPath: String?

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
            SpotLogic.shouldShow(callStatus: spot.callStatus, showWorkedBandModeSpots: settings.showWorkedBandModeSpots) &&
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
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                self?.reloadLogbook(force: false)
            }
        }
    }

    func reconnectClusters() {
        connectionStates = Dictionary(uniqueKeysWithValues: settings.clusters.map { ($0.id, .disconnected) })
        hub.start(servers: settings.clusters, reconnect: settings.reconnect, requestSkimmer: settings.requestSkimmerSpots, onSpot: { [weak self] raw in
            Task { @MainActor in self?.receive(raw) }
        }, onState: { [weak self] id, state, error in
            Task { @MainActor in
                self?.connectionStates[id] = state
                if let error { self?.connectionErrors[id] = error } else if state == .connected { self?.connectionErrors[id] = nil }
            }
        }, onLine: { [weak self] _, name, line in
            Task { @MainActor in self?.appendClusterLine(source: name, text: line) }
        })
    }

    func sendClusterCommand(_ rawCommand: String) {
        let command = rawCommand
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        guard !command.isEmpty else { lastAction = "Enter a cluster command first"; return }
        guard command.count <= 160 else { lastAction = "Cluster commands are limited to 160 characters"; return }

        let connected = Set(connectionStates.compactMap { $0.value == .connected ? $0.key : nil })
        let targets: Set<UUID>
        if let target = clusterCommandTarget {
            targets = connected.contains(target) ? [target] : []
        } else {
            targets = connected
        }
        guard !targets.isEmpty else { lastAction = "No selected cluster is connected"; return }

        let targetName = clusterCommandTarget.flatMap { id in settings.clusters.first(where: { $0.id == id })?.name } ?? "All connected"
        clusterConsole.append(ClusterConsoleLine(receivedAt: Date(), source: targetName, text: "> \(command)", isCommand: true))
        trimClusterConsole()
        hub.send(command: command, to: targets)
        customClusterCommand = ""
        lastAction = "Sent \(command) to \(targetName)"
    }

    func clearClusterConsole() { clusterConsole.removeAll() }

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
        guard !isLoadingLogbook else { return }
        let url = URL(fileURLWithPath: settings.logbookPath)
        let signature = logbookSignature(for: url)
        guard force || signature != lastLogbookSignature else { return }
        isLoadingLogbook = true; logbookStatus = "Reading \(url.lastPathComponent)…"
        Task { [weak self] in
            let outcome: (LogbookIndex?, String?) = await Task.detached(priority: .utility) {
                do { return (try LogbookIndex.load(url: url), nil) }
                catch { return (nil, error.localizedDescription) }
            }.value
            guard let self else { return }
            if let index = outcome.0 {
                let previous = logbook
                let standardizedPath = url.standardizedFileURL.path
                let hadPreviousSnapshot = previous.loadedAt != .distantPast && loadedLogbookPath == standardizedPath
                let newlyLogged = hadPreviousSnapshot ? Set(spots.compactMap { spot in
                    index.history(call: spot.callsign, country: spot.country).records.count > previous.history(call: spot.callsign, country: spot.country).records.count ? spot.callsign : nil
                }) : []
                logbook = index
                loadedLogbookPath = standardizedPath
                if !newlyLogged.isEmpty { spots.removeAll { newlyLogged.contains($0.callsign) } }
                reclassifyVisibleSpots()
                lastLogbookSignature = logbookSignature(for: url)
                logbookStatus = "\(index.recordCount.formatted()) contacts · read-only"
                if !newlyLogged.isEmpty { lastAction = "Removed \(newlyLogged.sorted().joined(separator: ", ")) after RUMlog logged the contact" }
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
        do {
            try RUMlogController().send(callsign: spot.callsign, frequencyKHz: spot.frequencyKHz, mode: spot.mode,
                                        note: settings.transferSpotNoteToRUMlog ? spot.comment : nil)
            let baseMessage = "Sent \(spot.callsign) · \(String(format: "%.6f", spot.frequencyKHz / 1000)) MHz to RUMlogNG"
            lastAction = baseMessage
            guard settings.rigCtlModeEnabled else { return }
            let host = settings.rigCtlHost, port = settings.rigCtlPort, frequency = spot.frequencyKHz, mode = spot.mode
            Task { [weak self] in
                let result = await Task.detached(priority: .userInitiated) {
                    Result { try RigCtlModeController(host: host, port: port).setMode(for: mode, frequencyKHz: frequency) }
                }.value
                guard let self else { return }
                switch result {
                case .success(let radioMode): self.lastAction = "\(baseMessage) · radio mode \(radioMode)"
                case .failure(let error): self.lastAction = "\(baseMessage) · mode handoff failed: \(error.localizedDescription)"
                }
            }
        }
        catch { lastAction = error.localizedDescription; NSSound.beep() }
    }

    func history(for spot: DXSpot) -> HistorySummary { logbook.history(call: spot.callsign, country: spot.country) }
    func clearFilters() { filter = SpotFilter() }

    func color(for status: String) -> Color { Color(hex: settings.statusPalette.colors[status] ?? "#B0B0B0") }

    private func reclassifyVisibleSpots() {
        for index in spots.indices {
            let status = logbook.classify(call: spots[index].callsign, band: spots[index].band, mode: spots[index].mode, adif: spots[index].country?.adif)
            spots[index].callStatus = status.0
            spots[index].dxccStatus = status.1
            spots[index].workedBefore = status.2
            let score = SpotLogic.score(callStatus: status.0, dxccStatus: status.1, specials: spots[index].specialTags, source: spots[index].source)
            spots[index].score = score.0
            spots[index].scoreReasons = score.1
        }
    }

    private func appendClusterLine(source: String, text: String) {
        clusterConsole.append(ClusterConsoleLine(receivedAt: Date(), source: source, text: text, isCommand: false))
        trimClusterConsole()
    }

    private func trimClusterConsole() {
        if clusterConsole.count > 400 { clusterConsole.removeFirst(clusterConsole.count - 400) }
    }

    private func logbookSignature(for url: URL) -> String {
        [url.path, url.path + "-wal"].map { path in
            guard let values = try? FileManager.default.attributesOfItem(atPath: path) else { return "missing" }
            let size = (values[.size] as? NSNumber)?.uint64Value ?? 0
            let modified = (values[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
            return "\(size):\(modified)"
        }.joined(separator: "|")
    }
}

extension Color {
    init(hex: String) {
        let text = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let value = UInt64(text, radix: 16) ?? 0xb0b0b0
        self.init(.sRGB, red: Double((value >> 16) & 0xff) / 255, green: Double((value >> 8) & 0xff) / 255, blue: Double(value & 0xff) / 255, opacity: 1)
    }
}
