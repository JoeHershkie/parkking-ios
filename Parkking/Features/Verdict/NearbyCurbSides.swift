import Foundation
import SwiftUI

enum NearbySideTone: Sendable, Equatable {
    case allowed
    case notAllowed
    case unclear

    nonisolated static func tone(for status: CurbVerdictStatus) -> NearbySideTone {
        switch status {
        case .parkingAllowed, .likelyAllowed:
            return .allowed
        case .notAllowed:
            return .notAllowed
        case .scheduleUnclear, .partiallyAllowed:
            return .unclear
        }
    }

    var color: Color {
        switch self {
        case .allowed: return .green
        case .notAllowed: return .red
        case .unclear: return .orange
        }
    }
}

struct NearbySideChip: Identifiable, Equatable, Sendable {
    var groupKey: String
    var letter: String
    var sideDisplay: String
    var status: CurbVerdictStatus

    var id: String { groupKey }

    nonisolated init(
        groupKey: String,
        letter: String,
        sideDisplay: String,
        status: CurbVerdictStatus
    ) {
        self.groupKey = groupKey
        self.letter = letter
        self.sideDisplay = sideDisplay
        self.status = status
    }

    var tone: NearbySideTone { NearbySideTone.tone(for: status) }

    nonisolated func accessibilityLabel(street: String) -> String {
        "\(street) \(sideDisplay)"
    }

    nonisolated var accessibilityValue: String {
        switch status {
        case .parkingAllowed: return "Parking allowed"
        case .likelyAllowed: return "Likely allowed"
        case .partiallyAllowed: return "Partially allowed"
        case .notAllowed: return "Not allowed"
        case .scheduleUnclear: return "Schedule unclear"
        }
    }
}

struct NearbyStreetRow: Identifiable, Equatable, Sendable {
    var street: String
    var sides: [NearbySideChip]

    var id: String { street }

    nonisolated init(street: String, sides: [NearbySideChip]) {
        self.street = street
        self.sides = sides
    }
}

enum NearbyCurbSides {
    nonisolated static func streetRows(
        groups: [CurbSideGroup],
        resolved: ResolvedTimeQuery
    ) -> [NearbyStreetRow] {
        var order: [String] = []
        var rows: [String: NearbyStreetRow] = [:]

        for group in groups {
            let verdict = CurbVerdictComposer.composeCurbVerdictForQuery(
                features: group.verdictFeatures,
                resolved: resolved,
                street: group.street,
                side: group.side,
                sideDisplay: group.sideDisplay
            )
            let chip = NearbySideChip(
                groupKey: group.groupKey,
                letter: SideNormalization.sideAbbrev(group.side),
                sideDisplay: group.sideDisplay,
                status: verdict.status
            )
            if var row = rows[group.street] {
                row.sides.append(chip)
                rows[group.street] = row
            } else {
                order.append(group.street)
                rows[group.street] = NearbyStreetRow(street: group.street, sides: [chip])
            }
        }

        return order.compactMap { street in
            guard var row = rows[street] else { return nil }
            row.sides.sort { SideNormalization.compareSideAbbrevs($0.letter, $1.letter) }
            return row
        }
    }
}
