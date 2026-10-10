import SwiftUI

@main
struct OM0RXXClusterApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("OM0RX-xCluster") {
            ContentView().environmentObject(model).frame(minWidth: 1180, minHeight: 680).preferredColorScheme(.dark).onAppear { model.start() }
        }
        .defaultSize(width: 1680, height: 920)
        .commands {
            CommandGroup(replacing: .appSettings) { Button("Settings…") { model.showingSettings = true }.keyboardShortcut(",", modifiers: .command) }
            CommandGroup(after: .appInfo) { Button("Reload RUMlog Logbook") { model.reloadLogbook(force: true) }.keyboardShortcut("r", modifiers: [.command, .shift]) }
            CommandMenu("Cluster") { Button("Reconnect All") { model.reconnectClusters() }; Button("Clear Filters") { model.clearFilters() }.keyboardShortcut("k", modifiers: [.command, .option]) }
        }
    }
}
