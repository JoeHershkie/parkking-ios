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
    case selected

    /// Draw allowed first, restrictions last, selection on top.
    nonisolated static let drawOrder: [ParkingOverlayBucketKind] = [
        .allowed,
        .allowedUncertain,
        .unclear,
        .unclearUncertain,
        .restricted,
        .restrictedUncertain,
        .selected,
    ]

    nonisolated var isSelected: Bool {
        self == .selected
    }

    nonisolated var strokeColor: UIColor {
        switch self {
        case .allowed, .allowedUncertain:
            return .systemGreen
        case .unclear, .unclearUncertain:
            return .systemOrange
        case .restricted, .restrictedUncertain:
            return .systemRed
        case .selected:
            return UIColor.label.withAlphaComponent(0.85)
        }
    }

    nonisolated var lineWidth: CGFloat {
        switch self {
        case .restricted, .restrictedUncertain:
            return 5
        case .selected:
            return 8
        default:
            return 3
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

enum ParkingOverlayStyling {
    struct Plan: Equatable, Sendable {
        var colorBuckets: [ParkingOverlayBucketKind: [ParkingMapRenderItem.ID]]
        var selectedIDs: [ParkingMapRenderItem.ID]
    }

    nonisolated static func colorKind(
        severity: Int,
        polarity: FilterPolarity,
        uncertain: Bool
    ) -> ParkingOverlayBucketKind {
        let restricted = severity == 2
            || polarity == .restricted
            || polarity == .notPermitted
        let unclear = polarity == .unknown
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
    /// Selected IDs are also listed separately and drawn on top.
    nonisolated static func plan(
        items: [ParkingMapRenderItem],
        selectedFeatureIDs: Set<String>
    ) -> Plan {
        var colorBuckets: [ParkingOverlayBucketKind: [ParkingMapRenderItem.ID]] = [:]
        var selectedIDs: [ParkingMapRenderItem.ID] = []
        for item in items {
            if selectedFeatureIDs.contains(item.id.featureID.rawValue) {
                selectedIDs.append(item.id)
            }
            let kind = colorKind(
                severity: item.severity,
                polarity: item.polarity,
                uncertain: item.isUncertainPlacement
            )
            colorBuckets[kind, default: []].append(item.id)
        }
        return Plan(colorBuckets: colorBuckets, selectedIDs: selectedIDs)
    }
}

final class ParkingStyledOverlay: MKMultiPolyline {
    let kind: ParkingOverlayBucketKind
    let itemIDs: [ParkingMapRenderItem.ID]

    init(kind: ParkingOverlayBucketKind, items: [ParkingMapRenderItem]) {
        self.kind = kind
        self.itemIDs = items.map(\.id)
        let polylines: [MKPolyline] = items.compactMap { item in
            guard item.coordinates.count >= 2 else { return nil }
            var coords = item.coordinates
            return MKPolyline(coordinates: &coords, count: coords.count)
        }
        super.init(polylines)
    }
}
