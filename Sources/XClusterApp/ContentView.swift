import AppKit
import SwiftUI
import XClusterCore

enum Theme {
    static let background = Color(hex: "#07111F"), surface = Color(hex: "#0B1728"), raised = Color(hex: "#101F34")
    static let rule = Color(hex: "#243A55"), text = Color(hex: "#E6EDF6"), secondary = Color(hex: "#92A7BF")
    static let cyan = Color(hex: "#35C8F5"), teal = Color(hex: "#12D6A0"), amber = Color(hex: "#F3B23C"), danger = Color(hex: "#FF6B5E")
    static let worked = Color(hex: "#FF8C00"), confirmed = Color(hex: "#10B981")
    static let tableHeader = Color(hex: "#3A3A3A"), tableRow = Color(hex: "#292B29"), tableRowAlternate = Color(hex: "#2E302D")
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
        .sheet(isPresented: $model.showingSettings) { SettingsView().environmentObject(model).preferredColorScheme(.dark).frame(width: 860, height: 680) }
    }

    private var statusRail: some View {
        HStack(spacing: 16) {
            Label("OM0RX-xCluster", systemImage: "dot.radiowaves.left.and.right").font(.headline).foregroundStyle(Theme.teal)
            Divider().frame(height: 18)
            connectionBadge
            Label(model.logbookStatus, systemImage: "externaldrive.badge.checkmark").foregroundStyle(model.logbook.recordCount > 0 ? Theme.text : Theme.amber)
            Button { model.showingClusterCommands.toggle() } label: {
                Label("Commands", systemImage: "terminal")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(model.connectedCount > 0 ? Theme.cyan : Theme.secondary)
            }
            .buttonStyle(.plain)
            .disabled(model.connectedCount == 0)
            .help(model.connectedCount > 0 ? "Send a command to one or more connected clusters" : "Connect to a cluster to send commands")
            .popover(isPresented: $model.showingClusterCommands, arrowEdge: .bottom) {
                ClusterCommandPanel().environmentObject(model)
            }
            Spacer()
            Text("\(min(model.filteredSpots.count, model.settings.maximumSpots)) shown · \(model.spots.count) loaded")
                .foregroundStyle(Theme.secondary).monospacedDigit()
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
                Menu { ForEach([50, 100, 200, 500], id: \.self) { count in Button(count == model.settings.maximumSpots ? "✓ \(count)" : "\(count)") { model.settings.maximumSpots = count } } } label: { FilterLabel(title: "Show: \(model.settings.maximumSpots)", icon: "list.number", active: false, accent: Color(hex: "#659DFF")) }.coloredFilter(accent: Color(hex: "#659DFF"), active: false)
                MultiSelectMenu(title: "Bands", icon: "waveform.path", values: SpotLogic.bands, selection: $model.filter.bands, accent: Theme.cyan)
                MultiSelectMenu(title: "Modes", icon: "dial.medium", values: SpotLogic.modes, selection: $model.filter.modes, accent: Color(hex: "#A78BFA"))
                MultiSelectMenu(title: "Continent", icon: "globe.europe.africa", values: ["AF", "AN", "AS", "EU", "NA", "OC", "SA"], selection: $model.filter.continents, accent: Color(hex: "#69D69A"))
                MultiSelectMenu(title: "Call Status", icon: "person.crop.circle.badge.questionmark", values: ["New Call", "New Band", "New Mode", "New Band+Mode", "Worked", "Confirmed"], selection: $model.filter.callStatuses, accent: Color(hex: "#FF8B5C"))
                MultiSelectMenu(title: "DXCC Status", icon: "trophy", values: ["ATNO", "C/New Band", "C/New Mode", "C/New Band+Mode", "W/New Band", "W/New Mode", "W/New Band+Mode", "Worked", "Confirmed", "Unknown"], selection: $model.filter.dxccStatuses, accent: Color(hex: "#F3C969"))
                MultiSelectMenu(title: "Special", icon: "star", values: model.settings.specialRules.filter(\.enabled).map(\.name), selection: $model.filter.specials, accent: Color(hex: "#F47BC5"))
                SourceSelectMenu(selection: $model.filter.sources)
                MultiSelectMenu(title: "Worked", icon: "checkmark.circle", values: ["Worked before", "Not worked"], selection: $model.filter.worked, accent: Color(hex: "#5FA8FF"))
                Menu { ForEach(SpotSort.allCases) { sort in Button(sort == model.filter.sort ? "✓ \(sort.rawValue)" : sort.rawValue) { model.filter.sort = sort } } } label: { FilterLabel(title: "Sort: \(model.filter.sort.rawValue)", icon: "arrow.up.arrow.down", active: model.filter.sort != .newest, accent: Color(hex: "#A78BFA")) }.coloredFilter(accent: Color(hex: "#A78BFA"), active: model.filter.sort != .newest)
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

    @ViewBuilder private var inspector: some View {
        if let spot = model.selectedSpot {
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 3) { Text(spot.callsign).font(.title3.bold()).foregroundStyle(Theme.teal); Text(spot.country?.name ?? "Country unresolved").foregroundStyle(Theme.secondary) }
                detail("Frequency", String(format: "%.6f MHz", spot.frequencyKHz / 1000))
                detail("Path", "\(spot.spotter) · \(spot.clusterName)")
                detail("Priority", "\(spot.score) · \(spot.scoreReasons.joined(separator: ", "))")
                detail("Comment", spot.comment.isEmpty ? "No cluster comment" : spot.comment)
                Spacer()
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

private struct ClusterCommandPanel: View {
    @EnvironmentObject private var model: AppModel
    @State private var copied = false

    private let quickCommands: [(String, String, String, String)] = [
        ("Recent DX", "Last 50 spots", "sh/dx/50", "clock.arrow.circlepath"),
        ("My DX", "Cluster-filtered spots", "sh/mydx 50", "line.3.horizontal.decrease.circle"),
        ("WWV", "Solar conditions", "sh/wwv/5", "sun.max"),
        ("WCY", "Propagation report", "sh/wcy/5", "waveform.path.ecg"),
        ("Announcements", "Last 10 notices", "sh/ann/10", "megaphone"),
        ("Users", "Connected operators", "sh/u", "person.2"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Label("Cluster commands", systemImage: "terminal.fill")
                    .font(.headline).foregroundStyle(Theme.teal)
                Spacer()
                Picker("Target", selection: $model.clusterCommandTarget) {
                    Text("All connected").tag(Optional<UUID>.none)
                    ForEach(model.settings.clusters.filter(\.enabled)) { server in
                        Text(server.name).tag(Optional(server.id))
                    }
                }
                .pickerStyle(.menu).labelsHidden().frame(width: 170)
                Button { model.showingClusterCommands = false } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain).help("Close")
            }
            .padding(14).background(Theme.surface)

            Divider().overlay(Theme.rule)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(quickCommands, id: \.2) { title, detail, command, icon in
                    Button { model.sendClusterCommand(command) } label: {
                        HStack(spacing: 9) {
                            Image(systemName: icon).frame(width: 18).foregroundStyle(Theme.cyan)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.text)
                                Text(detail).font(.caption2).foregroundStyle(Theme.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10).frame(height: 44)
                        .background(Theme.raised).clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.rule))
                    }
                    .buttonStyle(.plain).help("Send \(command)")
                }
            }
            .padding(12)

            HStack(spacing: 8) {
                Image(systemName: "chevron.right").foregroundStyle(Theme.teal)
                TextField("Custom command, for example: sh/dx 20 on 20m", text: $model.customClusterCommand)
                    .textFieldStyle(.plain).onSubmit { model.sendClusterCommand(model.customClusterCommand) }
                Button("Send") { model.sendClusterCommand(model.customClusterCommand) }
                    .buttonStyle(.borderedProminent).tint(Theme.teal)
                    .disabled(model.customClusterCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 10).frame(height: 36)
            .background(Theme.raised).clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.rule))
            .padding(.horizontal, 12).padding(.bottom, 12)

            HStack {
                Text("Cluster response").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondary)
                Spacer()
                Button(copied ? "Copied" : "Copy") { copyTranscript() }.buttonStyle(.borderless).disabled(model.clusterConsole.isEmpty)
                Button("Clear") { model.clearClusterConsole() }.buttonStyle(.borderless).disabled(model.clusterConsole.isEmpty)
            }
            .padding(.horizontal, 14).frame(height: 28).background(Theme.surface)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 5) {
                        if model.clusterConsole.isEmpty {
                            Text("Choose a command above. Its reply will appear here.")
                                .foregroundStyle(Theme.secondary).padding(.vertical, 18)
                        } else {
                            ForEach(model.clusterConsole) { line in
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text(line.receivedAt.formatted(date: .omitted, time: .standard))
                                        .foregroundStyle(Theme.secondary).monospacedDigit().frame(width: 70, alignment: .leading)
                                    Text(line.source).foregroundStyle(line.isCommand ? Theme.teal : Theme.cyan).frame(width: 92, alignment: .leading)
                                    Text(line.text).foregroundStyle(line.isCommand ? Theme.text : Color(hex: "#C8D4E3"))
                                        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .font(.system(size: 11, design: .monospaced)).id(line.id)
                            }
                        }
                    }
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Theme.background)
                .onChange(of: model.clusterConsole.count) { _ in
                    if let id = model.clusterConsole.last?.id {
                        withAnimation(.easeOut(duration: 0.16)) { proxy.scrollTo(id, anchor: .bottom) }
                    }
                }
            }
        }
        .frame(width: 660, height: 480).background(Theme.background).preferredColorScheme(.dark)
    }

    private func copyTranscript() {
        let transcript = model.clusterConsole.map { "[\($0.source)] \($0.text)" }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(transcript, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
    }
}

private struct FilterLabel: View {
    let title: String, icon: String, active: Bool, accent: Color
    var body: some View {
        Label(title, systemImage: icon)
            .font(.system(size: 12, weight: active ? .semibold : .medium))
            .foregroundStyle(accent)
    }
}

private struct MultiSelectMenu: View {
    let title: String, icon: String, values: [String]
    @Binding var selection: Set<String>
    let accent: Color
    @State private var showingOptions = false

    var body: some View {
        Button { showingOptions.toggle() } label: {
            HStack(spacing: 5) {
                FilterLabel(title: selection.isEmpty ? "\(title): All" : "\(title) · \(selection.count)", icon: icon, active: !selection.isEmpty, accent: accent)
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
            }
        }
        .buttonStyle(.plain)
        .coloredFilterBox(accent: accent, active: !selection.isEmpty)
        .popover(isPresented: $showingOptions, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.headline).padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 8)
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 9) {
                        Toggle("All", isOn: allBinding).toggleStyle(.checkbox).fontWeight(.semibold)
                        Divider()
                        ForEach(values, id: \.self) { value in
                            Toggle(value, isOn: optionBinding(value)).toggleStyle(.checkbox)
                        }
                    }.padding(12)
                }.frame(maxHeight: 360)
                Divider()
                HStack { Text(selection.isEmpty ? "All options" : "\(selection.count) selected").font(.caption).foregroundStyle(Theme.secondary); Spacer(); Button("Done") { showingOptions = false }.keyboardShortcut(.defaultAction) }.padding(10)
            }
            .frame(minWidth: 220)
            .background(Theme.surface)
            .preferredColorScheme(.dark)
        }
    }

    private var allBinding: Binding<Bool> {
        Binding(get: { selection.isEmpty }, set: { enabled in if enabled { selection.removeAll() } })
    }

    private func optionBinding(_ value: String) -> Binding<Bool> {
        Binding(get: { selection.contains(value) }, set: { enabled in if enabled { selection.insert(value) } else { selection.remove(value) } })
    }
}

private struct SourceSelectMenu: View {
    @Binding var selection: Set<String>
    @State private var showingOptions = false
    private let allSources: Set<String> = ["cluster", "rbl"]

    var body: some View {
        Button { showingOptions.toggle() } label: {
            HStack(spacing: 5) {
                FilterLabel(title: selection == allSources ? "Sources: All" : "Sources · \(selection.count)", icon: "antenna.radiowaves.left.and.right", active: selection != allSources, accent: Theme.teal)
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
            }
        }
        .buttonStyle(.plain)
        .coloredFilterBox(accent: Theme.teal, active: selection != allSources)
        .popover(isPresented: $showingOptions, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 9) {
                Text("Sources").font(.headline)
                Divider()
                Toggle("All", isOn: Binding(get: { selection == allSources }, set: { enabled in if enabled { selection = allSources } })).toggleStyle(.checkbox).fontWeight(.semibold)
                Divider()
                Toggle("DX Cluster", isOn: sourceBinding("cluster")).toggleStyle(.checkbox)
                Toggle("RBN / Skimmer", isOn: sourceBinding("rbl")).toggleStyle(.checkbox)
                Divider()
                HStack { Spacer(); Button("Done") { showingOptions = false }.keyboardShortcut(.defaultAction) }
            }
            .padding(12).frame(minWidth: 220).background(Theme.surface).preferredColorScheme(.dark)
        }
    }

    private func sourceBinding(_ source: String) -> Binding<Bool> {
        Binding(get: { selection.contains(source) }, set: { enabled in if enabled { selection.insert(source) } else { selection.remove(source) } })
    }
}

private extension View {
    func coloredFilter(accent: Color, active: Bool) -> some View {
        self.menuStyle(.borderlessButton)
            .fixedSize()
            .coloredFilterBox(accent: accent, active: active)
    }

    func coloredFilterBox(accent: Color, active: Bool) -> some View {
        self.fixedSize()
            .padding(.horizontal, 8)
            .frame(height: 27)
            .background(accent.opacity(active ? 0.30 : 0.17))
            .foregroundStyle(accent)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(accent.opacity(active ? 0.92 : 0.62)))
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
            .frame(height: 32).background(Theme.tableHeader).overlay(alignment: .bottom) { Rectangle().fill(Color(hex: "#4A4A4A")).frame(height: 1) }
    }

    private func row(_ spot: DXSpot, index: Int) -> some View {
        HStack(spacing: 0) {
            Button { tune(spot) } label: {
                HStack(spacing: 0) {
                    cell(spot.receivedAt.formatted(date: .omitted, time: .standard), 78).monospacedDigit()
                    scoreBadge(spot.score)
                    categoryCell(spot.band, 52, color: model.color(forBand: spot.band))
                    cell(String(format: "%.6f", spot.frequencyKHz / 1000), 90, color: Color(hex: "#4A9EFF")).monospacedDigit()
                }
            }.buttonStyle(.plain).help("Tune this spot in RUMlogNG")
            Button(spot.callsign) { model.historySpot = spot }.buttonStyle(.plain).fontWeight(.bold).foregroundStyle(Color(hex: "#10B981")).frame(width: 92, alignment: .leading).padding(.horizontal, 6).help("Show previous QSOs")
            Button { tune(spot) } label: {
                HStack(spacing: 0) {
                    categoryCell(spot.mode, 64, color: model.color(forMode: spot.mode))
                    cell(spot.country?.name.capitalized ?? "Unknown", 150, color: Color(hex: "#CCCCCC"))
                    cell(spot.country.map { String($0.cqZone) } ?? "–", 38)
                    cell(spot.aggregateCount > 1 ? "\(spot.spotter) +\(spot.aggregateCount - 1)" : spot.spotter, 92, color: Color(hex: "#CCCCCC"))
                    cell(spot.callStatus, 112, color: model.color(for: spot.callStatus), weight: .bold)
                    cell(spot.dxccStatus, 132, color: model.color(for: spot.dxccStatus), weight: .bold)
                    HStack(spacing: 4) { ForEach(spot.specialTags.prefix(2), id: \.self) { specialBadge($0) } }.frame(width: 132, alignment: .leading).padding(.horizontal, 6)
                    cell(spot.workedBefore.map { "✓ " + $0.formatted(date: .numeric, time: .omitted) } ?? "", 100, color: Theme.confirmed, weight: .medium)
                    cell(spot.comment, 280, color: Color(hex: "#AAAAAA"))
                }
            }.buttonStyle(.plain).help("Tune this spot in RUMlogNG")
        }
        .frame(height: 30).background(rowBackground(spot, index: index))
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule.opacity(0.45)).frame(height: 1) }
    }

    private func tune(_ spot: DXSpot) { model.selectedSpotID = spot.id; model.tune(spot) }

    private func cell(_ value: String, _ width: CGFloat, color: Color = Theme.text, weight: Font.Weight = .regular) -> some View {
        Text(value).font(.system(size: 12, weight: weight)).lineLimit(1).truncationMode(.tail).frame(width: width, alignment: .leading).padding(.horizontal, 6).foregroundStyle(color)
    }

    private func categoryCell(_ value: String, _ width: CGFloat, color: Color) -> some View {
        Text(value)
            .font(.system(size: 11, weight: .bold))
            .lineLimit(1)
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .frame(height: 20)
            .background(color.opacity(0.15))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(color.opacity(0.42), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .frame(width: width, alignment: .leading)
            .padding(.horizontal, 6)
    }

    private func scoreBadge(_ score: Int) -> some View {
        let colours: (Color, Color) = score >= 80 ? (Color(hex: "#7F1D1D"), Color(hex: "#FECACA")) :
            score >= 55 ? (Color(hex: "#854D0E"), Color(hex: "#FDE68A")) :
            score >= 30 ? (Color(hex: "#064E3B"), Color(hex: "#A7F3D0")) : (Color(hex: "#374151"), Color(hex: "#D1D5DB"))
        return Text("\(score)").font(.system(size: 11, weight: .bold)).padding(.horizontal, 6).frame(height: 20)
            .background(colours.0).foregroundStyle(colours.1).clipShape(RoundedRectangle(cornerRadius: 4))
            .frame(width: 48, alignment: .leading).padding(.horizontal, 6)
    }

    private func specialBadge(_ name: String) -> some View {
        let palette: (Color, Color, Color)
        switch name.uppercased() {
        case "POTA": palette = (Color(hex: "#5F3F2A"), Color(hex: "#FFD4B0"), Color(hex: "#A56F4A"))
        case "SOTA": palette = (Color(hex: "#3F5F2A"), Color(hex: "#D4FFB0"), Color(hex: "#6FA54A"))
        case "IOTA": palette = (Color(hex: "#5F2A5F"), Color(hex: "#FFD4FF"), Color(hex: "#A54AA5"))
        case "WWFF": palette = (Color(hex: "#2A5F5F"), Color(hex: "#B0FFFF"), Color(hex: "#4AA5A5"))
        case "CASTLE": palette = (Color(hex: "#5F5F2A"), Color(hex: "#FFFFD4"), Color(hex: "#A5A54A"))
        case "LIGHTHOUSE": palette = (Color(hex: "#4A5F2A"), Color(hex: "#D4FF94"), Color(hex: "#7AA54A"))
        case "CONTEST": palette = (Color(hex: "#5F3A2A"), Color(hex: "#FFC5A0"), Color(hex: "#A56A4A"))
        case "IARU": palette = (Color(hex: "#2A3A5F"), Color(hex: "#A0D4FF"), Color(hex: "#4A6AA5"))
        default: palette = (Color(hex: "#2A3F5F"), Color(hex: "#B0D4FF"), Color(hex: "#4A6FA5"))
        }
        return Text(name).font(.system(size: 9, weight: .bold)).padding(.horizontal, 5).padding(.vertical, 2)
            .background(palette.0).foregroundStyle(palette.1).clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(palette.2))
    }

    private func rowBackground(_ spot: DXSpot, index: Int) -> Color {
        if model.selectedSpotID == spot.id { return Color(hex: "#4A9EFF").opacity(0.40) }
        let status = spot.dxccStatus
        if status == "ATNO" { return Color(hex: "#FF8C00").opacity(0.15) }
        if status.contains("Band+Mode") { return Color(hex: "#E91E63").opacity(0.15) }
        if status.contains("New Band") { return Color(hex: "#00BFFF").opacity(0.15) }
        if status.contains("New Mode") { return Color(hex: "#FFC000").opacity(0.15) }
        if status == "Worked" { return Color(hex: "#B0B0B0").opacity(0.10) }
        if status == "Confirmed" { return Color(hex: "#646464").opacity(0.10) }
        return index.isMultiple(of: 2) ? Theme.tableRowAlternate : Theme.tableRow
    }

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
            HStack {
                Text("DXCC Band/Mode Matrix").font(.headline).foregroundStyle(Theme.teal)
                if let country = summary.country {
                    Text("\(country.name.capitalized) · \(summary.dxccRecords.count) contacts")
                        .font(.caption).foregroundStyle(Theme.secondary)
                }
            }
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow { Text("").matrixCell(header: true); ForEach(bands, id: \.self) { Text($0).matrixCell(header: true) } }
                ForEach(modes, id: \.self) { mode in GridRow { Text(mode).matrixCell(header: true); ForEach(bands, id: \.self) { band in matrixCell(mode: mode, band: band) } } }
            }.background(Theme.surface).overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.rule))
            HStack { Label("Worked", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.worked); Label("Confirmed", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.confirmed); Text("–  Not worked / not confirmed").foregroundStyle(Theme.secondary) }.font(.caption)
        }
    }

    private func matrixCell(mode: String, band: String) -> some View {
        let matches = summary.dxccRecords.filter { $0.mode == mode && $0.band == band }
        return Group { if matches.contains(where: \.isConfirmed) { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.confirmed) } else if !matches.isEmpty { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.worked) } else { Text("-").foregroundStyle(Theme.secondary) } }.frame(width: 68, height: 30).overlay(Rectangle().stroke(Theme.rule.opacity(0.55), lineWidth: 0.5))
    }
}

private extension View {
    func matrixCell(header: Bool) -> some View { self.font(.caption.bold()).foregroundStyle(Theme.text).frame(width: 68, height: 30).background(header ? Theme.raised : Color.clear).overlay(Rectangle().stroke(Theme.rule.opacity(0.55), lineWidth: 0.5)) }
}
