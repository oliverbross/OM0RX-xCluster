import AppKit
import SwiftUI
import XClusterCore

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var passwords: [UUID: String] = [:]
    @State private var selectedTab = "General"

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Picker("Settings section", selection: $selectedTab) {
                    Label("General", systemImage: "slider.horizontal.3").tag("General")
                    Label("Clusters", systemImage: "antenna.radiowaves.left.and.right").tag("Clusters")
                    Label("Status Colours", systemImage: "paintpalette").tag("Colours")
                    Label("Specials", systemImage: "star").tag("Specials")
                }.pickerStyle(.segmented)
                Button { dismiss() } label: { Image(systemName: "xmark").font(.headline) }
                    .buttonStyle(.plain).help("Close Settings").keyboardShortcut(.cancelAction)
            }.padding(16)
            Divider()
            Group {
                switch selectedTab {
                case "Clusters": clusters
                case "Colours": colours
                case "Specials": specials
                default: general
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            HStack {
                Text(model.lastAction).font(.caption).foregroundStyle(Theme.secondary)
                Spacer()
                Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save & Close") { save(); dismiss() }.buttonStyle(.borderedProminent).tint(Theme.teal).keyboardShortcut(.defaultAction)
            }.padding(14)
        }
        .background(Theme.background)
        .onAppear { for server in model.settings.clusters { passwords[server.id] = SettingsStore.shared.password(for: server.id) } }
    }

    private var general: some View {
        Form {
            Section("RUMlog logbook") {
                HStack { TextField("Choose a .rlog file", text: $model.settings.logbookPath); Button("Choose…") { model.chooseLogbook() } }
                Text("The file is opened with SQLite READONLY and query_only. xCluster never writes to the RUMlog database.").font(.caption).foregroundStyle(Theme.secondary)
                HStack { Text(model.logbookStatus); Spacer(); Button("Reload now") { model.reloadLogbook(force: true) } }
            }
            Section("Live table") {
                Picker("Maximum visible spots", selection: $model.settings.maximumSpots) { ForEach([50, 100, 200, 500], id: \.self) { Text(String($0)).tag($0) } }.frame(width: 220)
                Toggle("Reconnect clusters automatically", isOn: $model.settings.reconnect)
            }
            Section("RUMlogNG control") {
                Text("Double-clicking sends callsign, mode, log frequency and TX frequency through RUMlogNG's Apple-event interface. macOS will ask for Automation permission on first use.").font(.caption).foregroundStyle(Theme.secondary)
            }
        }.formStyle(.grouped).scrollContentBackground(.hidden)
    }

    private var clusters: some View {
        VStack(spacing: 10) {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(model.settings.clusters.indices, id: \.self) { index in clusterEditor(index) }
                }.padding(16)
            }
            HStack { Button { addCluster() } label: { Label("Add cluster", systemImage: "plus") }; Spacer(); Text("All enabled clusters connect simultaneously; duplicate reports are merged.").font(.caption).foregroundStyle(Theme.secondary) }.padding(.horizontal, 16).padding(.bottom, 10)
        }
    }

    private func clusterEditor(_ index: Int) -> some View {
        let serverID = model.settings.clusters[index].id
        return VStack(alignment: .leading, spacing: 10) {
            HStack { Toggle("", isOn: $model.settings.clusters[index].enabled).labelsHidden(); TextField("Name", text: $model.settings.clusters[index].name).font(.headline); Spacer(); stateLabel(serverID); Button(role: .destructive) { removeCluster(at: index) } label: { Image(systemName: "trash") }.buttonStyle(.borderless) }
            HStack { labeled("Host", TextField("cluster.example.com", text: $model.settings.clusters[index].host)); labeled("Port", TextField("7300", value: $model.settings.clusters[index].port, format: .number).frame(width: 80)); labeled("Callsign", TextField("OM0RX", text: $model.settings.clusters[index].callsign).frame(width: 100)); labeled("Password", SecureField("Optional", text: passwordBinding(serverID)).frame(width: 120)) }
            if let error = model.connectionErrors[serverID] { Text(error).font(.caption).foregroundStyle(Theme.danger) }
        }.padding(12).background(Theme.surface).clipShape(RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.rule))
    }

    private func stateLabel(_ id: UUID) -> some View {
        let state = model.connectionStates[id] ?? .disconnected
        return HStack(spacing: 5) { Circle().fill(state == .connected ? Theme.teal : state == .connecting ? Theme.amber : Theme.danger).frame(width: 7, height: 7); Text(state.rawValue.capitalized).font(.caption) }
    }

    private func labeled<Content: View>(_ title: String, _ content: Content) -> some View { VStack(alignment: .leading, spacing: 4) { Text(title.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(Theme.secondary); content.textFieldStyle(.roundedBorder) } }

    private var colours: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(model.settings.statusPalette.colors.keys.sorted(), id: \.self) { key in
                    HStack { Text(key).fontWeight(.semibold); Spacer(); ColorPicker("", selection: colorBinding(key), supportsOpacity: false).labelsHidden(); Text(model.settings.statusPalette.colors[key] ?? "").font(.system(.caption, design: .monospaced)).foregroundStyle(Theme.secondary) }
                        .padding(10).background(Theme.surface).clipShape(RoundedRectangle(cornerRadius: 6)).overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.rule))
                }
            }.padding(16)
            HStack { Button("Restore OM0RX defaults") { model.settings.statusPalette = .defaults }; Spacer() }.padding(.horizontal, 16)
        }
    }

    private var specials: some View {
        VStack(spacing: 10) {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(model.settings.specialRules.indices, id: \.self) { index in
                        specialEditor(index)
                    }
                }.padding(16)
            }
            HStack { Button { model.settings.specialRules.append(SpecialRule(name: "NEW", keywords: ["NEW"])) } label: { Label("Add special", systemImage: "plus") }; Spacer(); Text("Matches are case-insensitive. Separate words or phrases with commas.").font(.caption).foregroundStyle(Theme.secondary) }.padding(.horizontal, 16).padding(.bottom, 10)
        }
    }

    private func specialEditor(_ index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Toggle("Enabled", isOn: $model.settings.specialRules[index].enabled).labelsHidden()
                labeled("Badge shown in table", TextField("POTA", text: $model.settings.specialRules[index].name).frame(width: 150))
                labeled("Comment contains any of", TextField("POTA, Parks on the Air", text: keywordBinding(index)))
                Button(role: .destructive) { model.settings.specialRules.remove(at: index) } label: { Image(systemName: "trash") }.buttonStyle(.borderless).help("Remove this special")
            }
            HStack(alignment: .firstTextBaseline) {
                Text("Reference format").font(.caption2.weight(.semibold)).foregroundStyle(Theme.secondary)
                Picker("Reference format", selection: $model.settings.specialRules[index].referenceFormat) {
                    ForEach(SpecialReferenceFormat.allCases) { format in Text(format.title).tag(format) }
                }.labelsHidden().frame(maxWidth: 260)
                Text("Also recognise references such as the example shown.").font(.caption).foregroundStyle(Theme.secondary)
                Spacer()
            }
            DisclosureGroup("Advanced matching (optional)") {
                labeled("Regular expression", TextField("Leave empty unless you need an expert rule", text: $model.settings.specialRules[index].advancedPattern).font(.system(.body, design: .monospaced)))
                    .padding(.top, 6)
            }.font(.caption).foregroundStyle(Theme.secondary)
        }
        .padding(11).background(Theme.surface).clipShape(RoundedRectangle(cornerRadius: 7)).overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.rule))
    }

    private func keywordBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { model.settings.specialRules[index].keywords.joined(separator: ", ") },
            set: { value in
                model.settings.specialRules[index].keywords = value
                    .components(separatedBy: CharacterSet(charactersIn: ",;\n"))
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        )
    }

    private func passwordBinding(_ id: UUID) -> Binding<String> { Binding(get: { passwords[id] ?? "" }, set: { passwords[id] = $0 }) }

    private func colorBinding(_ key: String) -> Binding<Color> { Binding(get: { Color(hex: model.settings.statusPalette.colors[key] ?? "#B0B0B0") }, set: { model.settings.statusPalette.colors[key] = NSColor($0).hexRGB }) }

    private func addCluster() {
        let server = ClusterServer(name: "New cluster", host: "", port: 7300, callsign: model.settings.clusters.first?.callsign ?? "OM0RX", enabled: true)
        model.settings.clusters.append(server); passwords[server.id] = ""
    }

    private func removeCluster(at index: Int) { let id = model.settings.clusters[index].id; model.settings.clusters.remove(at: index); passwords[id] = nil; try? SettingsStore.shared.setPassword("", for: id) }

    private func save() {
        for server in model.settings.clusters { try? SettingsStore.shared.setPassword(passwords[server.id] ?? "", for: server.id) }
        model.saveSettings()
    }
}

private extension NSColor {
    var hexRGB: String {
        guard let rgb = usingColorSpace(.deviceRGB) else { return "#B0B0B0" }
        return String(format: "#%02X%02X%02X", Int(round(rgb.redComponent * 255)), Int(round(rgb.greenComponent * 255)), Int(round(rgb.blueComponent * 255)))
    }
}
