import CoreLocation
import Foundation
import MapKit
@testable import Parkking

@MainActor
final class MockLocationClient: LocationProviding {
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var servicesEnabled = true
    var lastLocation: CLLocation?
    weak var delegate: LocationClientDelegate?
    var requestWhenInUseCallCount = 0
    var requestLocationCallCount = 0
    var refreshCallCount = 0
    var nextLocation: CLLocation?
    var nextError: LocationClientError?

    func requestWhenInUsePermission() {
        requestWhenInUseCallCount += 1
    }

    func requestOneShotLocation() async throws -> CLLocation {
        requestLocationCallCount += 1
        if let nextError {
            throw nextError
        }
        if let nextLocation {
            lastLocation = nextLocation
            return nextLocation
        }
        throw LocationClientError.failed("No mock location")
    }

    func refreshAuthorizationStatus() {
        refreshCallCount += 1
    }
}

enum ParkingMapTestFixtures {
    static let queenNorth = CLLocationCoordinate2D(latitude: 43.6502, longitude: -79.4005)
    static let queenSouth = CLLocationCoordinate2D(latitude: 43.64985, longitude: -79.4005)
    static let toronto = ParkingMapConstants.torontoCenter
    static let vancouver = CLLocationCoordinate2D(latitude: 49.2827, longitude: -123.1207)

    static let zoomedOutRegion = MKCoordinateRegion(
        center: toronto,
        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
    )

    static let zoomedInRegion = ParkingMapConstants.neighborhoodRegion(around: toronto)

    static func line(
        street: String,
        side: String,
        coords: [[Double]],
        rule: String = "rule",
        category: String = "no_parking",
        id: Int,
        schedule: Schedule? = nil
    ) -> ParkingFeature {
        ParkingFeature(
            id: FeatureID(id),
            geometry: .lineString(coordinates: coords),
            properties: ParkingProperties(
                highway: street,
                rule: rule,
                scheduleCategory: category,
                side: side,
                max: nil,
                schedule: schedule
            )
        )
    }

    static func queenStreetDataset() -> ParkingDataset {
        let north = line(
            street: "Queen St",
            side: "N",
            coords: [[-79.4, 43.65], [-79.401, 43.65]],
            rule: "north rule",
            id: 0
        )
        let south = line(
            street: "Queen St",
            side: "South",
            coords: [[-79.4, 43.6499], [-79.401, 43.6499]],
            rule: "south rule",
            id: 1
        )
        return dataset([north, south])
    }

    static func dataset(_ features: [ParkingFeature]) -> ParkingDataset {
        ParkingDataset(
            features: features,
            index: ParkingSpatialIndex(
                collection: ParkingFeatureCollection(features: features)
            ),
            skippedPoints: 0,
            manifest: .bundled,
            byteSize: 0,
            sha256: "test"
        )
    }

    static func recentsStore() -> RecentsStore {
        let suite = "ParkkingTests.Recents.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return RecentsStore(defaults: defaults, key: suite)
    }

    static func viewModel(
        location: MockLocationClient? = nil,
        recents: RecentsStore? = nil,
        dataset: ParkingDataset? = nil,
        now: @escaping () -> Date = Date.init
    ) -> ParkingMapViewModel {
        ParkingMapViewModel(
            locationClient: location ?? MockLocationClient(),
            recentsStore: recents ?? recentsStore(),
            now: now,
            dataset: dataset ?? queenStreetDataset(),
            startsClock: false
        )
    }
}
