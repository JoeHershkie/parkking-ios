import CoreLocation
import MapKit
import Testing
@testable import Parkking

@MainActor
@Suite("LocationCoordinator")
struct LocationCoordinatorTests {
    private final class MockLocationDelegate: LocationCoordinatorDelegate {
        var didLocateCoordinate: CLLocationCoordinate2D?
        var didLocateRegion: MKCoordinateRegion?

        func locationCoordinatorDidLocate(coordinate: CLLocationCoordinate2D, region: MKCoordinateRegion) {
            didLocateCoordinate = coordinate
            didLocateRegion = region
        }
    }

    private final class MockLocationClient: LocationProviding {
        var authorizationStatus: CLAuthorizationStatus = .notDetermined
        var servicesEnabled: Bool = true
        var lastLocation: CLLocation?
        var isAuthorized: Bool {
            authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
        }
        var requestPermissionCallCount = 0
        var locationResult: Result<CLLocation, LocationClientError>?
        weak var delegate: LocationClientDelegate?

        func requestWhenInUsePermission() {
            requestPermissionCallCount += 1
        }

        func requestOneShotLocation() async throws -> CLLocation {
            if let locationResult {
                return try locationResult.get()
            }
            return CLLocation(latitude: 43.6532, longitude: -79.3832)
        }

        func refreshAuthorizationStatus() {}
    }

    @Test("undetermined status prompts for permission on tap")
    func undeterminedPromptsPermission() async {
        let client = MockLocationClient()
        client.authorizationStatus = .notDetermined
        let coordinator = LocationCoordinator(locationClient: client)

        await coordinator.tapLocateAsync()

        #expect(client.requestPermissionCallCount == 1)
        #expect(coordinator.locationError == nil)
    }

    @Test("services disabled sets error on tap")
    func servicesDisabledSetsError() async {
        let client = MockLocationClient()
        client.servicesEnabled = false
        let coordinator = LocationCoordinator(locationClient: client)

        await coordinator.tapLocateAsync()

        #expect(coordinator.locationError == .servicesDisabled)
    }

    @Test("authorized status locates and notifies delegate")
    func authorizedLocatesAndNotifiesDelegate() async {
        let client = MockLocationClient()
        client.authorizationStatus = .authorizedWhenInUse
        let targetCoord = CLLocationCoordinate2D(latitude: 43.651, longitude: -79.380)
        client.locationResult = .success(CLLocation(latitude: targetCoord.latitude, longitude: targetCoord.longitude))

        let coordinator = LocationCoordinator(locationClient: client)
        let delegate = MockLocationDelegate()
        coordinator.delegate = delegate

        await coordinator.tapLocateAsync()

        #expect(coordinator.isLocationCentered == true)
        #expect(coordinator.userCoordinate?.latitude == targetCoord.latitude)
        #expect(delegate.didLocateCoordinate?.latitude == targetCoord.latitude)
        #expect(delegate.didLocateRegion != nil)
    }

    @Test("centering detection checks visible region against user coordinate")
    func centeringDetection() {
        let client = MockLocationClient()
        let coordinator = LocationCoordinator(locationClient: client)
        let user = CLLocationCoordinate2D(latitude: 43.6532, longitude: -79.3832)

        let centeredRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 43.65321, longitude: -79.38321),
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )
        coordinator.updateUserCoordinate(user, visibleRegion: centeredRegion)
        #expect(coordinator.isLocationCentered == true)

        let offCenterRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 43.6600, longitude: -79.3900),
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )
        coordinator.updateCenteredState(with: offCenterRegion)
        #expect(coordinator.isLocationCentered == false)
    }
}
