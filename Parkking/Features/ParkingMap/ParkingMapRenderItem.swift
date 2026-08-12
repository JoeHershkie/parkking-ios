import CoreLocation
import Foundation
import MapKit
import SwiftUI

struct ParkingMapRenderItem: Identifiable, Sendable, Equatable {
    struct ID: Hashable, Sendable {
        var featureID: FeatureID
        var partIndex: Int
    }

    var id: ID
    var coordinates: [CLLocationCoordinate2D]
    var severity: Int
    var polarity: FilterPolarity
    var isSelected: Bool

    nonisolated init(
        featureID: FeatureID,
        partIndex: Int,
        coordinates: [CLLocationCoordinate2D],
        severity: Int,
        polarity: FilterPolarity,
        isSelected: Bool
    ) {
        self.id = ID(featureID: featureID, partIndex: partIndex)
        self.coordinates = coordinates
        self.severity = severity
        self.polarity = polarity
        self.isSelected = isSelected
    }

    nonisolated static func == (lhs: ParkingMapRenderItem, rhs: ParkingMapRenderItem) -> Bool {
        lhs.id == rhs.id
            && lhs.severity == rhs.severity
            && lhs.polarity == rhs.polarity
            && lhs.isSelected == rhs.isSelected
            && lhs.coordinates.count == rhs.coordinates.count
    }
}

enum ParkingMapConstants {
    /// Downtown Toronto, matching the web map.
    nonisolated static let torontoCenter = CLLocationCoordinate2D(
        latitude: 43.65,
        longitude: -79.38
    )

    /// Approximate MapLibre zoom 14.5 gate as max visible map width.
    nonisolated static let curbVisibleMaxWidthMeters: CLLocationDistance = 1_200

    nonisolated static let viewportPadDegrees = 0.01

    nonisolated static let torontoBounds = MapCameraBounds(
        centerCoordinateBounds: MKCoordinateRegion(
            center: torontoCenter,
            span: MKCoordinateSpan(latitudeDelta: 0.8, longitudeDelta: 1.4)
        ),
        minimumDistance: 200,
        maximumDistance: 80_000
    )
}
