import CoreLocation
import Foundation

protocol GeocodingProviding: Sendable {
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async -> String?
}

final class CLGeocodingClient: GeocodingProviding {
    private let geocoder = CLGeocoder()

    func reverseGeocode(coordinate: CLLocationCoordinate2D) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return nil }
            return Self.formatPlacemark(placemark)
        } catch {
            return nil
        }
    }

    nonisolated static func formatPlacemark(_ placemark: CLPlacemark) -> String? {
        if let subThoroughfare = placemark.subThoroughfare,
           let thoroughfare = placemark.thoroughfare {
            return "\(subThoroughfare) \(thoroughfare)"
        }
        if let thoroughfare = placemark.thoroughfare {
            return thoroughfare
        }
        if let name = placemark.name, !name.isEmpty {
            return name
        }
        return nil
    }
}

final class MockGeocodingClient: GeocodingProviding, @unchecked Sendable {
    var resultForCoordinate: [String: String] = [:]
    var defaultResult: String?
    var reverseGeocodeCallCount = 0
    private let lock = NSLock()

    init(defaultResult: String? = nil) {
        self.defaultResult = defaultResult
    }

    func setMock(coordinate: CLLocationCoordinate2D, address: String) {
        lock.lock()
        defer { lock.unlock() }
        let key = String(format: "%.5f,%.5f", coordinate.latitude, coordinate.longitude)
        resultForCoordinate[key] = address
    }

    func reverseGeocode(coordinate: CLLocationCoordinate2D) async -> String? {
        lock.lock()
        defer { lock.unlock() }
        reverseGeocodeCallCount += 1
        let key = String(format: "%.5f,%.5f", coordinate.latitude, coordinate.longitude)
        return resultForCoordinate[key] ?? defaultResult
    }
}
