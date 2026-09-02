import CoreLocation
import Foundation
import MapKit

protocol GeocodingProviding: Sendable {
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async -> String?
}

final class MapKitGeocodingClient: GeocodingProviding {
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        if #available(iOS 26.0, *) {
            if let request = MKReverseGeocodingRequest(location: location) {
                do {
                    let mapItems = try await request.mapItems
                    if let mapItem = mapItems.first, let formatted = Self.formatMapItem(mapItem) {
                        return formatted
                    }
                } catch {
                    // Fall back to CLGeocoder
                }
            }
        }

        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return nil }
            return Self.formatPlacemark(placemark)
        } catch {
            return nil
        }
    }

    private static func formatPlacemark(_ placemark: CLPlacemark) -> String? {
        if let streetNumber = placemark.subThoroughfare, let street = placemark.thoroughfare {
            return AddressFormatter.cleanAddress("\(streetNumber) \(street)")
        }
        if let name = placemark.name, let cleaned = AddressFormatter.cleanAddress(name) {
            return cleaned
        }
        if let street = placemark.thoroughfare, let cleaned = AddressFormatter.cleanAddress(street) {
            return cleaned
        }
        return nil
    }

    nonisolated static func formatMapItem(_ mapItem: MKMapItem) -> String? {
        if #available(iOS 26.0, *) {
            if let shortAddress = mapItem.address?.shortAddress, let cleaned = AddressFormatter.cleanAddress(shortAddress) {
                return cleaned
            }
            if let name = mapItem.name, let cleaned = AddressFormatter.cleanAddress(name) {
                return cleaned
            }
            if let fullAddress = mapItem.address?.fullAddress, let cleaned = AddressFormatter.cleanAddress(fullAddress) {
                return cleaned
            }
        }
        if let name = mapItem.name, let cleaned = AddressFormatter.cleanAddress(name) {
            return cleaned
        }
        return nil
    }
}

typealias CLGeocodingClient = MapKitGeocodingClient

final class MockGeocodingClient: GeocodingProviding, @unchecked Sendable {
    var resultForCoordinate: [String: String] = [:]
    var defaultResult: String?
    var reverseGeocodeCallCount = 0
    private let lock = NSLock()

    init(defaultResult: String? = nil) {
        self.defaultResult = defaultResult
    }

    func setMock(coordinate: CLLocationCoordinate2D, address: String) {
        lock.withLock {
            let key = String(format: "%.5f,%.5f", coordinate.latitude, coordinate.longitude)
            resultForCoordinate[key] = address
        }
    }

    func reverseGeocode(coordinate: CLLocationCoordinate2D) async -> String? {
        lock.withLock {
            reverseGeocodeCallCount += 1
            let key = String(format: "%.5f,%.5f", coordinate.latitude, coordinate.longitude)
            return resultForCoordinate[key] ?? defaultResult
        }
    }
}
