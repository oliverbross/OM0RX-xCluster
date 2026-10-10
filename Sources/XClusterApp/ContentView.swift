import AppKit
import SwiftUI
import XClusterCore

enum Theme {
    static let background = Color(hex: "#07111F"), surface = Color(hex: "#0B1728"), raised = Color(hex: "#101F34")
    static let rule = Color(hex: "#243A55"), text = Color(hex: "#E6EDF6"), secondary = Color(hex: "#92A7BF")
    static let cyan = Color(hex: "#35C8F5"), teal = Color(hex: "#12D6A0"), amber = Color(hex: "#F3B23C"), danger = Color(hex: "#FF6B5E")
    static let worked = Color(hex: "#FF8C00"), confirmed = Color(hex: "#10B981")
}

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            statusRail
            filterDeck
            SpotTable()
            inspector
        }
        .background(Theme.background)
        .sheet(item: $model.historySpot) { spot in HistorySheet(spot: spot).environmentObject(model) }
        .sheet(isPresented: $model.showingSettings) { SettingsView().environmentObject(model).preferredColorScheme(.dark).frame(width: 760, height: 600) }
    }

    private var statusRail: some View {
        HStack(spacing: 16) {
            Label("OM0RX-xCluster", systemImage: "dot.radiowaves.left.and.right").font(.headline).foregroundStyle(Theme.teal)
            Divider().frame(height: 18)
            connectionBadge
            Label(model.logbookStatus, systemImage: "externaldrive.badge.checkmark").foregroundStyle(model.logbook.recordCount > 0 ? Theme.text : Theme.amber)
            Spacer()
            Text("\(model.filteredSpots.count) shown · \(model.spots.count) live").foregroundStyle(Theme.secondary).monospacedDigit()
            Button { model.reconnectClusters() } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.plain).help("Reconnect all clusters")
            Button { model.showingSettings = true } label: { Image(systemName: "gearshape") }.buttonStyle(.plain).help("Settings")
        }
        .padding(.horizontal, 14).frame(height: 42).background(Theme.surface).overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
    }

    private var connectionBadge: some View {
        HStack(spacing: 7) {
            Circle().fill(model.connectedCount > 0 ? Theme.teal : Theme.danger).frame(width: 8, height: 8)
            Text(model.connectedCount == 0 ? "Cluster offline" : "\(model.connectedCount) cluster\(model.connectedCount == 1 ? "" : "s") live")
        }.foregroundStyle(model.connectedCount > 0 ? Theme.text : Theme.danger)
    }

    private var filterDeck: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu { ForEach([50, 100, 200, 500], id: \.self) { count in Button(count == model.settings.maximumSpots ? "✓ \(count)" : "\(count)") { model.settings.maximumSpots = count } } } label: { FilterLabel(title: "Show: \(model.settings.maximumSpots)", icon: "list.number", active: false, accent: Color(hex: "#659DFF")) }
                MultiSelectMenu(title: "Bands", icon: "waveform.path", values: SpotLogic.bands, selection: $model.filter.bands, accent: Theme.cyan)
                MultiSelectMenu(title: "Modes", icon: "dial.medium", values: SpotLogic.modes, selection: $model.filter.modes, accent: Color(hex: "#A78BFA"))
                MultiSelectMenu(title: "Continent", icon: "globe.europe.africa", values: ["AF", "AN", "AS", "EU", "NA", "OC", "SA"], selection: $model.filter.continents, accent: Color(hex: "#69D69A"))
                MultiSelectMenu(title: "Call Status", icon: "person.crop.circle.badge.questionmark", values: ["New Call", "New Band", "New Mode", "New Band+Mode", "Worked", "Confirmed"], selection: $model.filter.callStatuses, accent: Color(hex: "#FF8B5C"))
                MultiSelectMenu(title: "DXCC Status", icon: "trophy", values: ["ATNO", "C/New Band", "C/New Mode", "C/New Band+Mode", "W/New Band", "W/New Mode", "W/New Band+Mode", "Worked", "Confirmed", "Unknown"], selection: $model.filter.dxccStatuses, accent: Color(hex: "#F3C969"))
                MultiSelectMenu(title: "Special", icon: "star", values: model.settings.specialRules.filter(\.enabled).map(\.name), selection: $model.filter.specials, accent: Color(hex: "#F47BC5"))
                Menu {
                    Button("All") { model.filter.sources = ["cluster", "rbl"] }
                    Divider()
                    Toggle("DX Cluster", isOn: sourceBinding("cluster")); Toggle("RBN / Skimmer", isOn: sourceBinding("rbl"))
                } label: { FilterLabel(title: model.filter.sources == ["cluster", "rbl"] ? "Sources: All" : "Sources · \(model.filter.sources.count)", icon: "antenna.radiowaves.left.and.right", active: model.filter.sources != ["cluster", "rbl"], accent: Theme.teal) }
                MultiSelectMenu(title: "Worked", icon: "checkmark.circle", values: ["Worked before", "Not worked"], selection: $model.filter.worked, accent: Color(hex: "#5FA8FF"))
                Menu { ForEach(SpotSort.allCases) { sort in Button(sort == model.filter.sort ? "✓ \(sort.rawValue)" : sort.rawValue) { model.filter.sort = sort } } } label: { FilterLabel(title: "Sort: \(model.filter.sort.rawValue)", icon: "arrow.up.arrow.down", active: model.filter.sort != .newest, accent: Color(hex: "#A78BFA")) }
                if filtersActive { Button("Clear filters") { model.clearFilters() }.buttonStyle(.borderless).foregroundStyle(Theme.cyan) }
                HStack(spacing: 6) { Image(systemName: "magnifyingglass"); TextField("Call, country or comment", text: $model.filter.query).textFieldStyle(.plain) }
                    .padding(.horizontal, 9).frame(width: 250, height: 28).background(Theme.raised).clipShape(RoundedRectangle(cornerRadius: 6)).overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.rule))
            }
            .padding(.horizontal, 10)
        }
        .controlSize(.small).padding(.vertical, 9).background(Theme.surface).overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
    }

    private var filtersActive: Bool {
        !model.filter.query.isEmpty || !model.filter.bands.isEmpty || !model.filter.modes.isEmpty || !model.filter.continents.isEmpty || !model.filter.callStatuses.isEmpty || !model.filter.dxccStatuses.isEmpty || !model.filter.specials.isEmpty || !model.filter.worked.isEmpty || model.filter.sources != ["cluster", "rbl"]
    }

    private func sourceBinding(_ source: String) -> Binding<Bool> { Binding(get: { model.filter.sources.contains(source) }, set: { enabled in if enabled { model.filter.sources.insert(source) } else { model.filter.sources.remove(source) } }) }

    @ViewBuilder private var inspector: some View {
        if let spot = model.selectedSpot {
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 3) { Text(spot.callsign).font(.title3.bold()).foregroundStyle(Theme.teal); Text(spot.country?.name ?? "Country unresolved").foregroundStyle(Theme.secondary) }
                detail("Frequency", String(format: "%.6f MHz", spot.frequencyKHz / 1000))
                detail("Path", "\(spot.spotter) · \(spot.clusterName)")
                detail("Priority", "\(spot.score) · \(spot.scoreReasons.joined(separator: ", "))")
                detail("Comment", spot.comment.isEmpty ? "No cluster comment" : spot.comment)
                Spacer()
                Button("Previous QSOs") { model.historySpot = spot }
                Button("Tune RUMlogNG") { model.tune(spot) }.buttonStyle(.borderedProminent).tint(Theme.teal)
            }
            .padding(.horizontal, 14).frame(minHeight: 68).background(Theme.raised).overlay(alignment: .top) { Rectangle().fill(Theme.rule).frame(height: 1) }
        } else {
            HStack { Text(model.lastAction).foregroundStyle(Theme.secondary); Spacer(); Text("Select a spot for details").foregroundStyle(Theme.secondary) }
                .padding(.horizontal, 14).frame(height: 42).background(Theme.surface).overlay(alignment: .top) { Rectangle().fill(Theme.rule).frame(height: 1) }
        }
    }

    private func detail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) { Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(Theme.secondary); Text(value).lineLimit(2).foregroundStyle(Theme.text) }.frame(maxWidth: 270, alignment: .leading)
    }
}

private struct FilterLabel: View {
    let title: String, icon: String, active: Bool, accent: Color
    var body: some View {
        Label(title, systemImage: icon)
            .font(.system(size: 12, weight: active ? .semibold : .medium))
            .padding(.horizontal, 8)
            .frame(height: 27)
            .background(accent.opacity(active ? 0.30 : 0.17))
            .foregroundStyle(accent)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(accent.opacity(active ? 0.92 : 0.62)))
    }
}

private struct MultiSelectMenu: View {
    let title: String, icon: String, values: [String]
    @Binding var selection: Set<String>
    let accent: Color
    var body: some View {
        Menu {
            Button("All") { selection.removeAll() }
            Divider()
            ForEach(values, id: \.self) { value in
                Toggle(value, isOn: Binding(get: { selection.contains(value) }, set: { enabled in if enabled { selection.insert(value) } else { selection.remove(value) } }))
            }
        }
        label: { FilterLabel(title: selection.isEmpty ? "\(title): All" : "\(title) · \(selection.count)", icon: icon, active: !selection.isEmpty, accent: accent) }
    }
}

private struct SpotTable: View {
    @EnvironmentObject private var model: AppModel
    private let columns: [(String, CGFloat)] = [("Time", 78), ("Score", 48), ("Band", 52), ("Frequency", 90), ("Callsign", 92), ("Mode", 64), ("Country", 150), ("CQ", 38), ("DX de", 92), ("Call Status", 112), ("DXCC Status", 132), ("Special", 132), ("Worked b4", 100), ("Comment", 280)]

    var body: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section(header: header) {
                        ForEach(Array(model.filteredSpots.prefix(model.settings.maximumSpots).enumerated()), id: \.element.id) { index, spot in row(spot, index: index) }
                        if model.filteredSpots.isEmpty { emptyState.frame(width: max(geometry.size.width, 1100), height: max(geometry.size.height - 34, 260)) }
                    }
                }.frame(minWidth: 1500, alignment: .leading)
            }.background(Theme.background)
        }
    }

    private var header: some View {
        HStack(spacing: 0) { ForEach(columns, id: \.0) { name, width in Text(name).font(.caption.bold()).foregroundStyle(Theme.text).frame(width: width, alignment: .leading).padding(.horizontal, 6) } }
            .frame(height: 32).background(Theme.raised).overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
    }

    private func row(_ spot: DXSpot, index: Int) -> some View {
        HStack(spacing: 0) {
            cell(spot.receivedAt.formatted(date: .omitted, time: .standard), 78).monospacedDigit()
            Text("\(spot.score)").font(.caption.bold()).foregroundStyle(spot.score >= 60 ? Theme.amber : Theme.teal).frame(width: 48, alignment: .leading).padding(.horizontal, 6)
            cell(spot.band, 52).fontWeight(.semibold)
            cell(String(format: "%.6f", spot.frequencyKHz / 1000), 90).foregroundStyle(Theme.cyan).monospacedDigit()
            Button(spot.callsign) { model.historySpot = spot }.buttonStyle(.plain).fontWeight(.bold).foregroundStyle(Theme.teal).frame(width: 92, alignment: .leading).padding(.horizontal, 6).help("Show previous QSOs")
            cell(spot.mode, 64)
            cell(spot.country?.name.capitalized ?? "Unknown", 150)
            cell(spot.country.map { String($0.cqZone) } ?? "–", 38)
            cell(spot.aggregateCount > 1 ? "\(spot.spotter) +\(spot.aggregateCount - 1)" : spot.spotter, 92)
            cell(spot.callStatus, 112).foregroundStyle(model.color(for: spot.callStatus)).fontWeight(.bold)
            cell(spot.dxccStatus, 132).foregroundStyle(model.color(for: spot.dxccStatus)).fontWeight(.bold)
            HStack(spacing: 4) { ForEach(spot.specialTags.prefix(2), id: \.self) { Text($0).font(.system(size: 9, weight: .bold)).padding(.horizontal, 5).padding(.vertical, 2).background(Theme.amber.opacity(0.18)).foregroundStyle(Theme.amber).clipShape(RoundedRectangle(cornerRadius: 3)) } }.frame(width: 132, alignment: .leading).padding(.horizontal, 6)
            cell(spot.workedBefore.map { "✓ " + $0.formatted(date: .numeric, time: .omitted) } ?? "", 100).foregroundStyle(Theme.teal)
            cell(spot.comment, 280).foregroundStyle(Theme.secondary)
        }
        .frame(height: 30).background(model.selectedSpotID == spot.id ? Theme.cyan.opacity(0.16) : (index.isMultiple(of: 2) ? Theme.surface.opacity(0.7) : Theme.background))
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule.opacity(0.45)).frame(height: 1) }
        .contentShape(Rectangle()).onTapGesture(count: 2) { model.selectedSpotID = spot.id; model.tune(spot) }.onTapGesture { model.selectedSpotID = spot.id }
        .contextMenu { Button("Previous QSOs") { model.historySpot = spot }; Button("Tune RUMlogNG") { model.tune(spot) }; Divider(); Text("\(spot.aggregateCount) report\(spot.aggregateCount == 1 ? "" : "s") from \(spot.aggregateSpotters.joined(separator: ", "))") }
    }

    private func cell(_ value: String, _ width: CGFloat) -> some View { Text(value).font(.system(size: 12)).lineLimit(1).truncationMode(.tail).frame(width: width, alignment: .leading).padding(.horizontal, 6).foregroundStyle(Theme.text) }

    private var emptyState: some View {
        VStack(spacing: 10) { Image(systemName: model.connectedCount == 0 ? "antenna.radiowaves.left.and.right.slash" : "line.3.horizontal.decrease.circle").font(.system(size: 30)).foregroundStyle(Theme.secondary); Text(model.connectedCount == 0 ? "No cluster connection" : "No spots match the current filters").font(.headline); Text(model.connectedCount == 0 ? "Check the cluster callsign and network settings." : "Clear one or more filters to widen the live view.").foregroundStyle(Theme.secondary) }
    }
}

private struct HistorySheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let spot: DXSpot
    private let bands = ["160m", "80m", "60m", "40m", "30m", "20m", "17m", "15m", "12m", "10m", "6m"]
    private let modes = ["CW", "FT8", "FT4", "FT2", "RTTY", "SSB"]
    private var summary: HistorySummary { model.history(for: spot) }

    var body: some View {
        VStack(spacing: 0) {
            HStack { Label("Previous QSOs · \(spot.callsign)", systemImage: "clock.arrow.circlepath").font(.title3.bold()).foregroundStyle(Theme.teal); Spacer(); Button { dismiss() } label: { Image(systemName: "xmark") }.buttonStyle(.plain) }
                .padding(16).background(Theme.raised).overlay(alignment: .bottom) { Rectangle().fill(Theme.teal).frame(height: 2) }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(summary.records.isEmpty ? "Not worked before" : "\(summary.records.count) time\(summary.records.count == 1 ? "" : "s") worked before").font(.headline).foregroundStyle(summary.records.isEmpty ? Theme.amber : Theme.teal).padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Theme.raised).clipShape(RoundedRectangle(cornerRadius: 6))
                    if !summary.records.isEmpty { historyTable }
                    HStack(spacing: 10) { badge("DXCC", summary.country?.name.capitalized ?? "Unknown"); badge("ADIF", summary.country.map { String($0.adif) } ?? "–"); badge("CQ", summary.country.map { String($0.cqZone) } ?? "–"); badge("Gridsquare", summary.grid.isEmpty ? "Unknown" : summary.grid); Spacer() }
                    matrix
                }.padding(18)
            }
        }.frame(minWidth: 900, idealWidth: 1040, minHeight: 620, idealHeight: 760).background(Theme.background)
    }

    private var historyTable: some View {
        VStack(spacing: 0) {
            historyRow(["Date", "Callsign", "Mode", "RST (S)", "RST (R)", "Band", "LoTW"], header: true)
            ForEach(summary.records.prefix(20)) { qso in historyQsoRow(qso) }
            Text("Max. 20 previous contacts are shown").font(.caption.italic()).foregroundStyle(Theme.secondary).padding(8)
        }.background(Theme.surface).clipShape(RoundedRectangle(cornerRadius: 6)).overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.rule))
    }

    private func historyRow(_ values: [String], header: Bool) -> some View {
        HStack(spacing: 0) { ForEach(Array(values.enumerated()), id: \.offset) { index, value in Text(value).font(header ? .caption.bold() : .system(size: 12)).foregroundStyle(index == 1 && !header ? Theme.teal : Theme.text).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8) } }
            .frame(height: header ? 30 : 28).background(header ? Theme.raised : Color.clear).overlay(alignment: .bottom) { Rectangle().fill(Theme.rule.opacity(0.7)).frame(height: 1) }
    }

    private func historyQsoRow(_ qso: QSORecord) -> some View {
        let values = [qso.date.formatted(date: .numeric, time: .shortened), qso.callsign, qso.mode, qso.rstSent.isEmpty ? "–" : qso.rstSent, qso.rstReceived.isEmpty ? "–" : qso.rstReceived, qso.band]
        return HStack(spacing: 0) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                Text(value).font(.system(size: 12)).foregroundStyle(index == 1 ? Theme.teal : Theme.text).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8)
            }
            HStack(spacing: 1) {
                Text("▲").foregroundStyle(qso.lotwSent ? Theme.confirmed : Theme.secondary)
                Text("▼").foregroundStyle(qso.lotwReceived ? Theme.confirmed : Theme.secondary)
            }
            .font(.system(size: 12, weight: .bold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
        }
        .frame(height: 28)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule.opacity(0.7)).frame(height: 1) }
    }

    private func badge(_ label: String, _ value: String) -> some View { HStack(spacing: 5) { Text(label).foregroundStyle(Theme.secondary); Text(value).fontWeight(.semibold).foregroundStyle(Theme.teal) }.font(.caption).padding(.horizontal, 9).frame(height: 28).background(Theme.raised).clipShape(RoundedRectangle(cornerRadius: 5)).overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.rule)) }

    private var matrix: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Band/Mode Matrix").font(.headline).foregroundStyle(Theme.teal)
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow { Text("").matrixCell(header: true); ForEach(bands, id: \.self) { Text($0).matrixCell(header: true) } }
                ForEach(modes, id: \.self) { mode in GridRow { Text(mode).matrixCell(header: true); ForEach(bands, id: \.self) { band in matrixCell(mode: mode, band: band) } } }
            }.background(Theme.surface).overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.rule))
            HStack { Label("Worked", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.worked); Label("Confirmed", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.confirmed); Text("–  Not worked / not confirmed").foregroundStyle(Theme.secondary) }.font(.caption)
        }
    }

    private func matrixCell(mode: String, band: String) -> some View {
        let matches = summary.records.filter { $0.mode == mode && $0.band == band }
        return Group { if matches.contains(where: \.isConfirmed) { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.confirmed) } else if !matches.isEmpty { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.worked) } else { Text("-").foregroundStyle(Theme.secondary) } }.frame(width: 68, height: 30).overlay(Rectangle().stroke(Theme.rule.opacity(0.55), lineWidth: 0.5))
    }
}

private extension View {
    func matrixCell(header: Bool) -> some View { self.font(.caption.bold()).foregroundStyle(Theme.text).frame(width: 68, height: 30).background(header ? Theme.raised : Color.clear).overlay(Rectangle().stroke(Theme.rule.opacity(0.55), lineWidth: 0.5)) }
}
