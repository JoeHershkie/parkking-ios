import CoreLocation
import Foundation

enum LocationClientError: Error, Equatable, Sendable {
    case denied
    case restricted
    case servicesDisabled
    case failed(String)

    var bannerMessage: String {
        switch self {
        case .denied:
            return "Location permission denied."
        case .restricted:
            return "Location access is restricted on this device."
        case .servicesDisabled:
            return "Turn on Location Services to use your current location."
        case .failed(let message):
            return message
        }
    }

    var canOpenSettings: Bool {
        self == .denied
    }
}

@MainActor
protocol LocationClientDelegate: AnyObject {
    func locationClientDidChangeAuthorization(_ client: LocationProviding)
}

@MainActor
protocol LocationProviding: AnyObject {
    var authorizationStatus: CLAuthorizationStatus { get }
    var servicesEnabled: Bool { get }
    var lastLocation: CLLocation? { get }
    var isAuthorized: Bool { get }
    var delegate: LocationClientDelegate? { get set }

    func requestWhenInUsePermission()
    func requestOneShotLocation() async throws -> CLLocation
    func refreshAuthorizationStatus()
}

extension LocationProviding {
    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
}

@MainActor
final class LocationClient: NSObject, LocationProviding, CLLocationManagerDelegate {
    private let manager: CLLocationManager
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var servicesEnabled: Bool
    private(set) var lastLocation: CLLocation?

    weak var delegate: LocationClientDelegate?

    override init() {
        let manager = CLLocationManager()
        self.manager = manager
        self.authorizationStatus = manager.authorizationStatus
        self.servicesEnabled = true
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        Task.detached {
            let enabled = CLLocationManager.locationServicesEnabled()
            await MainActor.run { [weak self] in
                self?.servicesEnabled = enabled
            }
        }
    }

    func requestWhenInUsePermission() {
        manager.requestWhenInUseAuthorization()
    }

    func requestOneShotLocation() async throws -> CLLocation {
        authorizationStatus = manager.authorizationStatus
        let enabled = await Task.detached { CLLocationManager.locationServicesEnabled() }.value
        servicesEnabled = enabled
        if !servicesEnabled {
            throw LocationClientError.servicesDisabled
        }
        switch authorizationStatus {
        case .denied:
            throw LocationClientError.denied
        case .restricted:
            throw LocationClientError.restricted
        case .notDetermined:
            throw LocationClientError.failed("Location permission is not determined.")
        case .authorizedAlways, .authorizedWhenInUse:
            break
        @unknown default:
            break
        }

        if let current = manager.location,
           current.horizontalAccuracy >= 0 && current.horizontalAccuracy <= 100,
           current.timestamp.timeIntervalSinceNow > -30 {
            self.lastLocation = current
            return current
        }

        if let locationContinuation {
            locationContinuation.resume(
                throwing: LocationClientError.failed("Location request was replaced.")
            )
            self.locationContinuation = nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.locationContinuation = continuation
            manager.requestLocation()
        }
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = manager.authorizationStatus
        Task.detached {
            let enabled = CLLocationManager.locationServicesEnabled()
            await MainActor.run { [weak self] in
                self?.servicesEnabled = enabled
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task.detached {
            let enabled = CLLocationManager.locationServicesEnabled()
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.authorizationStatus = status
                self.servicesEnabled = enabled
                self.delegate?.locationClientDidChangeAuthorization(self)
            }
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        Task { @MainActor in
            guard let location = locations.last else { return }
            self.lastLocation = location
            self.locationContinuation?.resume(returning: location)
            self.locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            let mapped: LocationClientError
            if let clError = error as? CLError, clError.code == .denied {
                mapped = .denied
            } else {
                mapped = .failed(error.localizedDescription)
            }
            self.locationContinuation?.resume(throwing: mapped)
            self.locationContinuation = nil
        }
    }
}
