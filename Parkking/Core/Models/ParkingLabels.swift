import Foundation

enum ParkingLabels {
    nonisolated private static let categoryLabels: [String: String] = [
        "no_parking": "No parking",
        "no_stopping": "No stopping",
        "no_standing": "No standing",
        "restricted_periods": "Allowed periods",
    ]

    nonisolated static func scheduleCategoryLabel(_ category: String) -> String {
        if let label = categoryLabels[category] {
            return label
        }
        return category.replacingOccurrences(of: "_", with: " ")
    }

    nonisolated static func formatAllowedPeriodDuration(max: String?, maxMinutes: Int?) -> String? {
        if let maxMinutes, maxMinutes > 0 {
            if maxMinutes % 60 == 0 {
                let hours = maxMinutes / 60
                return "\(hours) hr"
            } else if maxMinutes < 60 {
                return "\(maxMinutes) min"
            } else {
                let h = maxMinutes / 60
                let m = maxMinutes % 60
                return "\(h) hr \(m) min"
            }
        }
        guard let max, !max.isEmpty else { return nil }
        let lower = max.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if lower == "1 hour" || lower == "1 hr" || lower == "1 hr." || lower == "1h" {
            return "1 hr"
        }
        if lower.contains("hour") || lower.contains("hr") {
            let digits = lower.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if !digits.isEmpty {
                return "\(digits) hr"
            }
        }
        if lower.contains("min") {
            let digits = lower.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if !digits.isEmpty {
                return "\(digits) min"
            }
        }
        return max
    }

    nonisolated static func formatMax(_ max: String?) -> String? {
        guard let max, !max.isEmpty else { return nil }
        return max
    }

    nonisolated static func formatMaxStay(max: String?, maxMinutes: Int?) -> String? {
        if let text = formatMax(max) {
            return text
        }
        guard let maxMinutes, maxMinutes > 0 else { return nil }
        if maxMinutes % 60 == 0, maxMinutes >= 60 {
            let hours = maxMinutes / 60
            return hours == 1 ? "1 hour" : "\(hours) hours"
        }
        return "\(maxMinutes) min"
    }

    /// Stable source-derived key for highlight/selection across updates.
    /// Prefers `_id` so a Both MultiLineString stays one rule.
    nonisolated static func ruleFeatureKey(_ props: ParkingProperties) -> String {
        if let sourceID = props.sourceID, !sourceID.isEmpty {
            return sourceID
        }
        return [
            props.highway,
            props.rule,
            props.side,
            props.scheduleCategory,
            props.max ?? "",
        ].joined(separator: "|")
    }
}
