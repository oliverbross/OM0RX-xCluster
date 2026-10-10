import Foundation

public final class CTYResolver: @unchecked Sendable {
    private struct Rule {
        var token: String
        var exact: Bool
        var country: CountryInfo
    }

    private let rules: [Rule]
    private let ignoredSuffixes: Set<String> = ["P", "M", "MM", "AM", "QRP", "QRPP", "A", "B", "QTH"]

    public init(csvURL: URL) throws {
        let text = try String(contentsOf: csvURL, encoding: .utf8)
        var parsed: [Rule] = []
        for line in text.split(whereSeparator: \ .isNewline) {
            let columns = Self.csvColumns(String(line))
            guard columns.count >= 9, let adif = Int(columns[2]), let cq = Int(columns[4]), let itu = Int(columns[5]) else { continue }
            let info = CountryInfo(name: columns[1].uppercased(), adif: adif, continent: columns[3].uppercased(), cqZone: cq,
                                   ituZone: itu, latitude: Double(columns[6]), longitude: Double(columns[7]).map { -$0 })
            let tokenText = columns.count > 9 ? columns[9] : columns[0]
            let tokens = ([columns[0]] + tokenText.split(whereSeparator: { $0 == " " || $0 == ";" }).map(String.init))
            for raw in tokens {
                let exact = raw.hasPrefix("=")
                let cleaned = Self.cleanToken(raw)
                if !cleaned.isEmpty { parsed.append(Rule(token: cleaned, exact: exact, country: info)) }
            }
        }
        rules = parsed.sorted { lhs, rhs in
            lhs.token.count == rhs.token.count ? (lhs.exact && !rhs.exact) : lhs.token.count > rhs.token.count
        }
    }

    public static func bundled() throws -> CTYResolver {
        guard let url = Bundle.module.url(forResource: "cty", withExtension: "csv") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try CTYResolver(csvURL: url)
    }

    public func resolve(_ rawCallsign: String) -> CountryInfo? {
        let call = rawCallsign.uppercased().filter { $0.isLetter || $0.isNumber || $0 == "/" }
        if call == "PJ6Y" || call.hasPrefix("PJ") {
            return rules.first(where: { $0.country.adif == 305 })?.country
        }
        var candidates = [call]
        candidates.append(contentsOf: call.split(separator: "/").map(String.init).filter { !ignoredSuffixes.contains($0) }.sorted { $0.count > $1.count })
        for candidate in candidates {
            for rule in rules {
                if rule.exact ? candidate == rule.token : candidate.hasPrefix(rule.token) {
                    if rule.token == "KG4", candidate.range(of: #"^KG4[A-Z]{3}$"#, options: .regularExpression) != nil,
                       rule.country.name.contains("GUANTANAMO") { continue }
                    return rule.country
                }
            }
        }
        return nil
    }

    private static func cleanToken(_ raw: String) -> String {
        var token = raw.uppercased().trimmingCharacters(in: CharacterSet(charactersIn: "*=;"))
        token = token.replacingOccurrences(of: #"\([^)]*\)|\[[^]]*\]|<[^>]*>"#, with: "", options: .regularExpression)
        return token.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func csvColumns(_ line: String) -> [String] {
        var columns: [String] = [], current = "", quoted = false
        for character in line {
            if character == "\"" { quoted.toggle() }
            else if character == "," && !quoted { columns.append(current.trimmingCharacters(in: .whitespaces)); current = "" }
            else { current.append(character) }
        }
        columns.append(current.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ";"))))
        return columns
    }
}
