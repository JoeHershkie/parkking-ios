import CoreLocation
import Foundation
import MapKit
import Observation
import UIKit

@MainActor
protocol LocationCoordinatorDelegate: AnyObject {
    func locationCoordinatorDidLocate(coordinate: CLLocationCoordinate2D, region: MKCoordinateRegion)
}

@MainActor
@Observable
final class LocationCoordinator {
    let locationClient: any LocationProviding
    var isLocating = false
    var locationError: LocationClientError?
    var isLocationAuthorized = false
    var isLocationCentered = false
    private(set) var userCoordinate: CLLocationCoordinate2D?
    private var didAutoLocateThisLaunch = false
    private var awaitingFirstGrant = false
    weak var delegate: LocationCoordinatorDelegate?

    init(locationClient: (any LocationProviding)? = nil) {
        let client = locationClient ?? LocationClient()
        self.locationClient = client
        self.isLocationAuthorized = client.isAuthorized
    }

    func maybeAutoLocate() async {
        guard !didAutoLocateThisLaunch else { return }
        guard locationClient.servicesEnabled else { return }
        guard locationClient.isAuthorized else { return }
        didAutoLocateThisLaunch = true
        await performLocate()
    }

    func tapLocate() {
        Task { await tapLocateAsync() }
    }

    func tapLocateAsync() async {
        locationError = nil

        if !locationClient.servicesEnabled {
            locationError = .servicesDisabled
            return
        }

        switch locationClient.authorizationStatus {
        case .notDetermined:
            awaitingFirstGrant = true
            locationClient.requestWhenInUsePermission()
        case .restricted:
            locationError = .restricted
        case .denied:
            locationError = .denied
        case .authorizedAlways, .authorizedWhenInUse:
            await performLocate()
        @unknown default:
            break
        }
    }

    func handleAuthorizationChange() async {
        isLocationAuthorized = locationClient.isAuthorized
        if !locationClient.servicesEnabled {
            locationError = .servicesDisabled
            awaitingFirstGrant = false
            return
        }

        switch locationClient.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locationError = nil
            if awaitingFirstGrant {
                awaitingFirstGrant = false
                await performLocate()
            } else {
                await maybeAutoLocate()
            }
        case .denied:
            locationError = .denied
            awaitingFirstGrant = false
        case .restricted:
            locationError = .restricted
            awaitingFirstGrant = false
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }

    func performLocate() async {
        isLocating = true
        defer { isLocating = false }
        do {
            let location = try await locationClient.requestOneShotLocation()
            didAutoLocateThisLaunch = true
            userCoordinate = location.coordinate
            isLocationCentered = true
            let region = ParkingMapConstants.neighborhoodRegion(around: location.coordinate)
            delegate?.locationCoordinatorDidLocate(coordinate: location.coordinate, region: region)
        } catch let error as LocationClientError {
            locationError = error
        } catch {
            locationError = .failed(error.localizedDescription)
        }
    }

    func updateUserCoordinate(_ coordinate: CLLocationCoordinate2D, visibleRegion: MKCoordinateRegion?) {
        userCoordinate = coordinate
        updateCenteredState(with: visibleRegion)
    }

    func updateCenteredState(with visibleRegion: MKCoordinateRegion?) {
        if let userCoordinate, let visibleRegion {
            let latDelta = abs(visibleRegion.center.latitude - userCoordinate.latitude)
            let lngDelta = abs(visibleRegion.center.longitude - userCoordinate.longitude)
            isLocationCentered = latDelta < 0.0005 && lngDelta < 0.0005
        } else {
            isLocationCentered = false
        }
    }
}
