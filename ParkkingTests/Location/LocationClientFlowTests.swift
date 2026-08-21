import CoreLocation
import Foundation
import Testing
@testable import Parkking

@MainActor
@Suite("Location permission and GPS")
struct LocationClientFlowTests {
    @Test("does not prompt on launch when authorization is undetermined")
    func doesNotPromptWhenUndetermined() async {
        let location = MockLocationClient()
        location.authorizationStatus = .notDetermined
        let vm = ParkingMapTestFixtures.viewModel(location: location)
        await vm.start()
        #expect(location.requestWhenInUseCallCount == 0)
        #expect(location.requestLocationCallCount == 0)
        #expect(vm.isLocationAuthorized == false)
    }

    @Test("first GPS tap requests When In Use and locates after grant")
    func firstGrantLocatesImmediately() async {
        let location = MockLocationClient()
        location.authorizationStatus = .notDetermined
        location.nextLocation = CLLocation(
            latitude: ParkingMapTestFixtures.queenNorth.latitude,
            longitude: ParkingMapTestFixtures.queenNorth.longitude
        )
        let recents = ParkingMapTestFixtures.recentsStore()
        let vm = ParkingMapTestFixtures.viewModel(location: location, recents: recents)
        await vm.start()
        await vm.tapLocateAsync()
        #expect(location.requestWhenInUseCallCount == 1)
        #expect(location.requestLocationCallCount == 0)

        location.authorizationStatus = .authorizedWhenInUse
        await vm.handleAuthorizationChange()
        #expect(location.requestLocationCallCount == 1)
        #expect(vm.lastSelectionSource == .gps)
        #expect(vm.lastFlownRegion != nil)
        #expect(vm.locationLabel == "Current location")
        #expect(recents.recents.isEmpty)
        #expect(vm.isLocationAuthorized)
    }

    @Test("auto-locates once per launch when already granted")
    func autoLocatesOnceWhenAlreadyGranted() async {
        let location = MockLocationClient()
        location.authorizationStatus = .authorizedWhenInUse
        location.nextLocation = CLLocation(
            latitude: ParkingMapTestFixtures.queenNorth.latitude,
            longitude: ParkingMapTestFixtures.queenNorth.longitude
        )
        let vm = ParkingMapTestFixtures.viewModel(location: location)
        await vm.start()
        #expect(location.requestWhenInUseCallCount == 0)
        #expect(location.requestLocationCallCount == 1)
        await vm.start()
        #expect(location.requestLocationCallCount == 1)
    }

    @Test("denied, restricted, and services-off set banner copy")
    func permissionErrors() async {
        let denied = MockLocationClient()
        denied.authorizationStatus = .denied
        let deniedVM = ParkingMapTestFixtures.viewModel(location: denied)
        await deniedVM.start()
        await deniedVM.tapLocateAsync()
        #expect(deniedVM.locationError == .denied)
        #expect(deniedVM.locationError?.canOpenSettings == true)
        #expect(denied.requestLocationCallCount == 0)

        let restricted = MockLocationClient()
        restricted.authorizationStatus = .restricted
        let restrictedVM = ParkingMapTestFixtures.viewModel(location: restricted)
        await restrictedVM.tapLocateAsync()
        #expect(restrictedVM.locationError == .restricted)
        #expect(restrictedVM.locationError?.canOpenSettings == false)

        let off = MockLocationClient()
        off.servicesEnabled = false
        off.authorizationStatus = .authorizedWhenInUse
        let offVM = ParkingMapTestFixtures.viewModel(location: off)
        await offVM.tapLocateAsync()
        #expect(offVM.locationError == .servicesDisabled)
        #expect(off.requestLocationCallCount == 0)
    }

    @Test("returning from Settings re-reads authorization")
    func settingsReturnRereadsAuthorization() async {
        let location = MockLocationClient()
        location.authorizationStatus = .denied
        let vm = ParkingMapTestFixtures.viewModel(location: location)
        await vm.start()
        await vm.tapLocateAsync()
        #expect(vm.locationError == .denied)

        location.authorizationStatus = .authorizedWhenInUse
        location.nextLocation = CLLocation(
            latitude: ParkingMapTestFixtures.queenNorth.latitude,
            longitude: ParkingMapTestFixtures.queenNorth.longitude
        )
        location.refreshAuthorizationStatus()
        await vm.handleAuthorizationChange()
        #expect(location.refreshCallCount >= 1)
        #expect(vm.isLocationAuthorized)
        #expect(location.requestLocationCallCount == 1)
        #expect(vm.locationError == nil)
    }
}
