import Foundation
import MapKit
import UIKit

enum ParkingOverlayBucketKind: String, Hashable, Sendable {
    case allowed
    case allowedUncertain
    case unclear
    case unclearUncertain
    case restricted
    case restrictedUncertain

    /// Draw allowed first, then unclear, restrictions last.
    nonisolated static let drawOrder: [ParkingOverlayBucketKind] = [
        .allowed,
        .allowedUncertain,
        .unclear,
        .unclearUncertain,
        .restricted,
        .restrictedUncertain,
    ]

    nonisolated var strokeColor: UIColor {
        switch self {
        case .allowed, .allowedUncertain:
            return .systemGreen
        case .unclear, .unclearUncertain:
            return .systemOrange
        case .restricted, .restrictedUncertain:
            return .systemRed
        }
    }

    /// Base width for all regular segment types. Uncertain segments are thinner than confident curb segments.
    nonisolated var lineWidth: CGFloat {
        switch self {
        case .allowedUncertain, .unclearUncertain, .restrictedUncertain:
            return 3
        default:
            return 5
        }
    }

    nonisolated var lineCap: CGLineCap {
        switch self {
        case .allowedUncertain, .unclearUncertain, .restrictedUncertain:
            return .butt
        default:
            return .round
        }
    }

    nonisolated var alpha: CGFloat {
        switch self {
        case .allowedUncertain, .unclearUncertain, .restrictedUncertain:
            return 0.45
        default:
            return 1
        }
    }

    nonisolated var dashPattern: [NSNumber] {
        switch self {
        case .allowedUncertain, .unclearUncertain, .restrictedUncertain:
            return [7, 5]
        default:
            return []
        }
    }
}

enum ParkingOverlayRole: Sendable {
    case base
    case selectedBorder
    case selectedFill
}

enum ParkingOverlayStyling {
    nonisolated static let selectedLineWidth: CGFloat = 8
    nonisolated static let selectedBorderWidth: CGFloat = 11
    nonisolated static let selectedBorderColor: UIColor = .black

    struct Plan: Equatable, Sendable {
        var colorBuckets: [ParkingOverlayBucketKind: [ParkingMapRenderItem.ID]]
        var selectedIDs: [ParkingMapRenderItem.ID]
        var selectedBuckets: [ParkingOverlayBucketKind: [ParkingMapRenderItem.ID]]
    }

    nonisolated static func colorKind(
        severity: Int,
        polarity: FilterPolarity,
        uncertain: Bool
    ) -> ParkingOverlayBucketKind {
        let restricted = severity == 2
            || polarity == .restricted
            || polarity == .notPermitted
        let unclear = polarity == .unknown || polarity == .partial || severity == 1
        let base: ParkingOverlayBucketKind
        if restricted {
            base = uncertain ? .restrictedUncertain : .restricted
        } else if unclear {
            base = uncertain ? .unclearUncertain : .unclear
        } else {
            base = uncertain ? .allowedUncertain : .allowed
        }
        return base
    }

    /// Color buckets keep every visible part so deselect can drop only the selected overlay.
    /// Selected IDs and selected buckets are also grouped for layered rendering.
    nonisolated static func plan(
        items: [ParkingMapRenderItem],
        selectedFeatureIDs: Set<String>
    ) -> Plan {
        var colorBuckets: [ParkingOverlayBucketKind: [ParkingMapRenderItem.ID]] = [:]
        var selectedIDs: [ParkingMapRenderItem.ID] = []
        var selectedBuckets: [ParkingOverlayBucketKind: [ParkingMapRenderItem.ID]] = [:]
        for item in items {
            let kind = colorKind(
                severity: item.severity,
                polarity: item.polarity,
                uncertain: item.isUncertainPlacement
            )
            colorBuckets[kind, default: []].append(item.id)
            if selectedFeatureIDs.contains(item.id.featureID.rawValue) {
                selectedIDs.append(item.id)
                selectedBuckets[kind, default: []].append(item.id)
            }
        }
        return Plan(
            colorBuckets: colorBuckets,
            selectedIDs: selectedIDs,
            selectedBuckets: selectedBuckets
        )
    }
}

final class ParkingStyledOverlay: MKMultiPolyline {
    let kind: ParkingOverlayBucketKind
    let role: ParkingOverlayRole
    let itemIDs: [ParkingMapRenderItem.ID]

    init(
        kind: ParkingOverlayBucketKind,
        role: ParkingOverlayRole = .base,
        items: [ParkingMapRenderItem]
    ) {
        self.kind = kind
        self.role = role
        self.itemIDs = items.map(\.id)
        let polylines: [MKPolyline] = items.compactMap { item in
            guard item.coordinates.count >= 2 else { return nil }
            var coords = item.coordinates
            return MKPolyline(coordinates: &coords, count: coords.count)
        }
        super.init(polylines)
    }

    var strokeColor: UIColor {
        switch role {
        case .base, .selectedFill:
            return kind.alpha == 1 ? kind.strokeColor : kind.strokeColor.withAlphaComponent(kind.alpha)
        case .selectedBorder:
            let alpha: CGFloat = kind.alpha == 1 ? 1.0 : 0.85
            return alpha == 1 ? ParkingOverlayStyling.selectedBorderColor : ParkingOverlayStyling.selectedBorderColor.withAlphaComponent(alpha)
        }
    }

    var lineWidth: CGFloat {
        switch role {
        case .base:
            return kind.lineWidth
        case .selectedFill:
            return ParkingOverlayStyling.selectedLineWidth
        case .selectedBorder:
            return ParkingOverlayStyling.selectedBorderWidth
        }
    }

    var lineCap: CGLineCap {
        switch role {
        case .base:
            return kind.lineCap
        case .selectedFill, .selectedBorder:
            return .round
        }
    }

    var dashPattern: [NSNumber] {
        kind.dashPattern
    }
}
