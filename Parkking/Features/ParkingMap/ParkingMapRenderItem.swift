import CoreLocation
import Foundation
import MapKit

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
    var isUncertainPlacement: Bool

    nonisolated init(
        featureID: FeatureID,
        partIndex: Int,
        coordinates: [CLLocationCoordinate2D],
        severity: Int,
        polarity: FilterPolarity,
        isSelected: Bool,
        isUncertainPlacement: Bool = false
    ) {
        self.id = ID(featureID: featureID, partIndex: partIndex)
        self.coordinates = coordinates
        self.severity = severity
        self.polarity = polarity
        self.isSelected = isSelected
        self.isUncertainPlacement = isUncertainPlacement
    }

    nonisolated static func == (lhs: ParkingMapRenderItem, rhs: ParkingMapRenderItem) -> Bool {
        lhs.id == rhs.id
            && lhs.severity == rhs.severity
            && lhs.polarity == rhs.polarity
            && lhs.isSelected == rhs.isSelected
            && lhs.isUncertainPlacement == rhs.isUncertainPlacement
            && lhs.coordinates.count == rhs.coordinates.count
    }
}

enum ParkingMapConstants {
    /// Downtown Toronto, matching the web map.
    nonisolated static let torontoCenter = CLLocationCoordinate2D(
        latitude: 43.65,
        longitude: -79.38
    )

    nonisolated static let citySpan = MKCoordinateSpan(
        latitudeDelta: 0.08,
        longitudeDelta: 0.08
    )

    nonisolated static let cityRegion = MKCoordinateRegion(
        center: torontoCenter,
        span: citySpan
    )

    nonisolated static let minCameraDistance: CLLocationDistance = 200
    nonisolated static let maxCameraDistance: CLLocationDistance = 80_000
    nonisolated static let chromeTopMargin: CGFloat = 88
    nonisolated static let chromeBottomMargin: CGFloat = 196

    /// Approximate MapLibre zoom 14.5 gate as max visible map width.
    nonisolated static let curbVisibleMaxWidthMeters: CLLocationDistance = 1_200

    nonisolated static let viewportPadDegrees = 0.01

    /// Envelope matching the bundled Toronto parking snapshot / camera bounds.
    nonisolated static let parkingCoverageSpan = MKCoordinateSpan(
        latitudeDelta: 0.8,
        longitudeDelta: 1.4
    )

    nonisolated static let parkingCoverageRegion = MKCoordinateRegion(
        center: torontoCenter,
        span: parkingCoverageSpan
    )

    /// Neighborhood-scale fly-to, below the 1.2 km curb-visibility gate.
    nonisolated static let neighborhoodSpan = MKCoordinateSpan(
        latitudeDelta: 0.004,
        longitudeDelta: 0.006
    )

    nonisolated static func neighborhoodRegion(
        around coordinate: CLLocationCoordinate2D
    ) -> MKCoordinateRegion {
        MKCoordinateRegion(center: coordinate, span: neighborhoodSpan)
    }

    nonisolated static func visibleWidthMeters(_ region: MKCoordinateRegion) -> CLLocationDistance {
        let lat = region.center.latitude * .pi / 180
        let metersPerDegreeLng = cos(lat) * 111_320
        return abs(region.span.longitudeDelta) * metersPerDegreeLng
    }

    nonisolated static func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let halfLat = parkingCoverageRegion.span.latitudeDelta / 2
        let halfLng = parkingCoverageRegion.span.longitudeDelta / 2
        let latMin = parkingCoverageRegion.center.latitude - halfLat
        let latMax = parkingCoverageRegion.center.latitude + halfLat
        let lngMin = parkingCoverageRegion.center.longitude - halfLng
        let lngMax = parkingCoverageRegion.center.longitude + halfLng
        return coordinate.latitude >= latMin
            && coordinate.latitude <= latMax
            && coordinate.longitude >= lngMin
            && coordinate.longitude <= lngMax
    }
}
