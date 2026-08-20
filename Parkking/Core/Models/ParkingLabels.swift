import Foundation

enum ParkingLabels {
    nonisolated private static let categoryLabels: [String: String] = [
        "no_parking": "No parking",
        "no_stopping": "No stopping",
        "no_standing": "No standing",
        "restricted_periods": "Restricted periods",
    ]

    nonisolated static func scheduleCategoryLabel(_ category: String) -> String {
        if let label = categoryLabels[category] {
            return label
        }
        return category.replacingOccurrences(of: "_", with: " ")
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
    nonisolated static func ruleFeatureKey(_ props: ParkingProperties) -> String {
        [
            props.highway,
            props.rule,
            props.side,
            props.scheduleCategory,
            props.max ?? "",
        ].joined(separator: "|")
    }
}
