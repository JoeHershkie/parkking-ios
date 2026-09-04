import Foundation

enum AddressFormatter {
    nonisolated private static let boroughNames: Set<String> = [
        "north york",
        "east york",
        "old toronto",
        "york",
        "etobicoke",
        "scarborough",
        "toronto",
        "city of toronto",
        "metropolitan toronto",
        "metro toronto",
        "downtown toronto",
        "downtown",
        "ontario",
        "on",
        "canada",
    ]

    nonisolated private static let streetTypeReplacements: [String: String] = [
        "street": "st",
        "st.": "st",
        "avenue": "ave",
        "ave.": "ave",
        "road": "rd",
        "rd.": "rd",
        "boulevard": "blvd",
        "blvd.": "blvd",
        "drive": "dr",
        "dr.": "dr",
        "crescent": "cres",
        "cres.": "cres",
        "place": "pl",
        "pl.": "pl",
        "court": "ct",
        "ct.": "ct",
        "lane": "ln",
        "ln.": "ln",
        "way": "way",
        "terrace": "ter",
        "ter.": "ter",
        "parkway": "pkwy",
        "pkwy.": "pkwy",
        "square": "sq",
        "sq.": "sq",
        "circle": "cir",
        "cir.": "cir",
        "trail": "trl",
        "trl.": "trl",
        "highway": "hwy",
        "hwy.": "hwy",
    ]

    nonisolated private static let directionalReplacements: [String: String] = [
        "west": "w",
        "w.": "w",
        "east": "e",
        "e.": "e",
        "north": "n",
        "n.": "n",
        "south": "s",
        "s.": "s",
    ]

    nonisolated private static let prefixReplacements: [String: String] = [
        "saint": "st",
        "st.": "st",
        "mount": "mt",
        "mt.": "mt",
    ]

    /// Cleans an address string by removing borough names (e.g. "North York", "York"),
    /// city, province, postal codes, and country components.
    nonisolated static func cleanAddress(_ raw: String?) -> String? {
        guard let raw else { return nil }
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return nil }

        // Remove postal codes (e.g., M5M 1T3 or M5M1T3)
        let postalCodeRegex = #"\b[A-Z]\d[A-Z]\s*\d[A-Z]\d\b"#
        text = text.replacingOccurrences(of: postalCodeRegex, with: "", options: .regularExpression, range: nil)

        // Split by comma and filter out borough, city, province, country tokens
        let parts = text.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { part in
                guard !part.isEmpty else { return false }
                let lower = part.lowercased()
                return !boroughNames.contains(lower)
            }

        guard let firstPart = parts.first, !firstPart.isEmpty else {
            return nil
        }

        // Clean up redundant trailing punctuation or spaces
        let cleaned = firstPart
            .trimmingCharacters(in: CharacterSet(charactersIn: ",. "))
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

        // If the cleaned result is itself just a known borough or empty, return nil
        if boroughNames.contains(cleaned.lowercased()) || cleaned.isEmpty {
            return nil
        }

        return cleaned
    }

    /// Normalizes a street name or address into a comparable array of standardized tokens.
    /// E.g. "12 Barse Street" -> ["barse", "st"]
    /// E.g. "Barse St" -> ["barse", "st"]
    /// E.g. "551 Fairlawn Ave" -> ["fairlawn", "ave"]
    nonisolated static func normalizeStreetTokens(_ streetOrAddress: String) -> [String] {
        guard let cleaned = cleanAddress(streetOrAddress) ?? (streetOrAddress.isEmpty ? nil : streetOrAddress) else {
            return []
        }

        let rawTokens = cleaned
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }

        // Drop leading house/building numbers if present (e.g. "551", "12A")
        var startIndex = 0
        while startIndex < rawTokens.count {
            let tok = rawTokens[startIndex]
            // If token starts with digits, it's likely a street number (e.g. 551, 100b)
            if let first = tok.first, first.isNumber {
                startIndex += 1
            } else {
                break
            }
        }

        let streetTokens = Array(rawTokens[startIndex...])

        return streetTokens.compactMap { token in
            if let dir = directionalReplacements[token] {
                return dir
            }
            if let type = streetTypeReplacements[token] {
                return type
            }
            if let prefix = prefixReplacements[token] {
                return prefix
            }
            return token
        }
    }

    /// Checks if a candidate address matches the target street name corresponding to a bylaw segment.
    nonisolated static func streetNamesMatch(address: String?, targetStreet: String?) -> Bool {
        guard let address, let targetStreet else { return false }
        let addrTokens = normalizeStreetTokens(address)
        let targetTokens = normalizeStreetTokens(targetStreet)

        guard !addrTokens.isEmpty, !targetTokens.isEmpty else { return false }

        // Exact token match
        if addrTokens == targetTokens {
            return true
        }

        // Base name match (the first non-prefix token, e.g. "barse" in ["barse", "st"])
        guard let addrBase = baseStreetToken(from: addrTokens),
              let targetBase = baseStreetToken(from: targetTokens) else {
            return false
        }

        if addrBase == targetBase {
            // If base names match, verify direction if both specify it (e.g. "w" vs "e")
            let addrDir = addrTokens.first(where: { ["n", "s", "e", "w"].contains($0) })
            let targetDir = targetTokens.first(where: { ["n", "s", "e", "w"].contains($0) })

            if let addrDir, let targetDir, addrDir != targetDir {
                return false
            }

            return true
        }

        return false
    }

    /// Extracts the core identifying name token from normalized tokens (ignoring type/direction suffixes).
    nonisolated private static func baseStreetToken(from tokens: [String]) -> String? {
        let typeOrDirSet: Set<String> = [
            "st", "ave", "rd", "blvd", "dr", "cres", "pl", "ct", "ln", "way", "ter", "pkwy", "sq", "cir", "trl", "hwy",
            "n", "s", "e", "w"
        ]
        return tokens.first(where: { !typeOrDirSet.contains($0) })
    }

    /// Checks if a string looks like a coordinate or generic placeholder.
    nonisolated static func isCoordinateOrGeneric(_ text: String?) -> Bool {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return true
        }
        if text == "Current location" || text == "Dropped Pin" || text.contains("°") {
            return true
        }
        let parts = text.split(separator: ",")
        if parts.count == 2 {
            let p0 = parts[0].trimmingCharacters(in: .whitespaces)
            let p1 = parts[1].trimmingCharacters(in: .whitespaces)
            if Double(p0) != nil && Double(p1) != nil {
                return true
            }
        }
        return false
    }

    /// Checks if a string contains tokens indicating a street name or address.
    nonisolated static func isAddressLike(_ text: String?) -> Bool {
        guard let text, !isCoordinateOrGeneric(text) else { return false }
        let tokens = normalizeStreetTokens(text)
        guard !tokens.isEmpty else { return false }
        let streetTypes: Set<String> = [
            "st", "ave", "rd", "blvd", "dr", "cres", "pl", "ct", "ln", "way", "ter", "pkwy", "sq", "cir", "trl", "hwy"
        ]
        return tokens.contains(where: { streetTypes.contains($0) })
    }

    /// Extracts a candidate street name from a title and/or subtitle.
    nonisolated static func extractStreetName(title: String?, subtitle: String? = nil) -> String? {
        if let title, !isCoordinateOrGeneric(title), isAddressLike(title) {
            return streetNameWithoutNumber(from: title)
        }
        if let subtitle, !isCoordinateOrGeneric(subtitle), isAddressLike(subtitle) {
            return streetNameWithoutNumber(from: subtitle)
        }
        return nil
    }

    /// Removes leading house / building numbers from an address string to leave the street name.
    /// E.g. "100 Queen St W" -> "Queen St W"
    /// E.g. "12 Barse Street" -> "Barse Street"
    /// E.g. "551A Fairlawn Ave" -> "Fairlawn Ave"
    nonisolated static func streetNameWithoutNumber(from address: String) -> String {
        guard let cleaned = cleanAddress(address) ?? (address.isEmpty ? nil : address) else {
            return address
        }
        let pattern = #"^\s*\d+[\w\-/]*\s+"#
        if let range = cleaned.range(of: pattern, options: .regularExpression) {
            let result = String(cleaned[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !result.isEmpty {
                return result
            }
        }
        return cleaned
    }
}
