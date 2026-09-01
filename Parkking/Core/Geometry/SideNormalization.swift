import Foundation

enum SideNormalization {
    nonisolated private static let sideAliases: [String: String] = [
        "n": "North",
        "north": "North",
        "northbound": "North",
        "n/b": "North",
        "nb": "North",
        "s": "South",
        "south": "South",
        "southbound": "South",
        "s/b": "South",
        "sb": "South",
        "e": "East",
        "east": "East",
        "eastbound": "East",
        "e/b": "East",
        "eb": "East",
        "w": "West",
        "west": "West",
        "westbound": "West",
        "w/b": "West",
        "wb": "West",
        "both": "Both",
        "both sides": "Both",
        "either": "Either",
        "either side": "Either",
    ]

    nonisolated private static let cardinalLetter: [String: String] = [
        "North": "N",
        "South": "S",
        "East": "E",
        "West": "W",
    ]

    nonisolated private static let sideLetterOrder = ["N", "S", "E", "W"]

    nonisolated static func normalizeSide(_ side: String?) -> String {
        guard let side, !side.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Unknown"
        }
        let key = side.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return sideAliases[key] ?? titleCaseSide(side.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    nonisolated private static func titleCaseSide(_ value: String) -> String {
        value
            .split(whereSeparator: \.isWhitespace)
            .map { part in
                guard let first = part.first else { return String(part) }
                return String(first).uppercased() + part.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }

    nonisolated static func normalizeStreet(_ street: String?) -> String {
        guard let street, !street.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Unknown street"
        }
        let cleaned = AddressFormatter.cleanAddress(street) ?? street
        return cleaned
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    nonisolated static func curbGroupKey(street: String, side: String) -> String {
        "\(normalizeStreet(street).lowercased())|\(normalizeSide(side).lowercased())"
    }

    nonisolated static func formatSideLabel(_ side: String) -> String {
        let normalized = normalizeSide(side)
        if normalized == "Both" || normalized == "Either" { return normalized }
        if normalized == "Unknown" { return "Unknown side" }
        return "\(normalized) side"
    }

    nonisolated static func sideAbbrev(_ side: String) -> String {
        let normalized = normalizeSide(side)
        if normalized == "Both" || normalized == "Either" { return "B" }
        if normalized == "Unknown" { return "?" }

        if let direct = cardinalLetter[normalized] {
            return direct
        }

        var found: [String] = []
        for (name, letter) in cardinalLetter {
            if normalized.range(of: #"\b\#(name)\b"#, options: [.regularExpression, .caseInsensitive])
                != nil
            {
                found.append(letter)
            }
        }
        if found.isEmpty {
            return String(normalized.prefix(1)).uppercased()
        }

        let ordered = sideLetterOrder.filter { found.contains($0) }
        return ordered.isEmpty ? found.joined() : ordered.joined()
    }

    nonisolated static func compareSideAbbrevs(_ a: String, _ b: String) -> Bool {
        let ai = sideLetterOrder.firstIndex(of: a) ?? 99
        let bi = sideLetterOrder.firstIndex(of: b) ?? 99
        if ai != bi { return ai < bi }
        return a < b
    }
}
