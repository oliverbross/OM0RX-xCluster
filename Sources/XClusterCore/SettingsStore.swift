import Foundation
import Security

public final class SettingsStore {
    public static let shared = SettingsStore()
    private let key = "OM0RX-xCluster.settings.v1"
    private let encoder = JSONEncoder(), decoder = JSONDecoder()

    public func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: key), var settings = try? decoder.decode(AppSettings.self, from: data) else { return .defaults }
        // ShackCQ reserves the unsuffixed station identity for its local console.
        // Preserve existing user configuration while migrating the original default.
        for index in settings.clusters.indices
        where settings.clusters[index].host.caseInsensitiveCompare("cluster.shackcq.com") == .orderedSame
            && ["OM0RX", "OM0RX-11"].contains(settings.clusters[index].callsign.uppercased()) {
            settings.clusters[index].callsign = "OM0RX-12"
        }
        return settings
    }

    public func save(_ settings: AppSettings) throws {
        UserDefaults.standard.set(try encoder.encode(settings), forKey: key)
    }

    public func password(for serverID: UUID) -> String {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: "com.oliverbross.OM0RXXCluster.cluster",
                                    kSecAttrAccount as String: serverID.uuidString,
                                    kSecReturnData as String: true]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    public func setPassword(_ password: String, for serverID: UUID) throws {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: "com.oliverbross.OM0RXXCluster.cluster",
                                   kSecAttrAccount as String: serverID.uuidString]
        SecItemDelete(base as CFDictionary)
        guard !password.isEmpty else { return }
        var add = base; add[kSecValueData as String] = Data(password.utf8)
        let result = SecItemAdd(add as CFDictionary, nil)
        guard result == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(result)) }
    }
}
