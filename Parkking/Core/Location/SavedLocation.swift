import CoreLocation
import Foundation

struct SavedLocation: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var label: String
    var latitude: Double
    var longitude: Double
    var savedAt: Date

    nonisolated init(
        id: String,
        label: String,
        latitude: Double,
        longitude: Double,
        savedAt: Date
    ) {
        self.id = id
        self.label = label
        self.latitude = latitude
        self.longitude = longitude
        self.savedAt = savedAt
    }

    nonisolated var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    nonisolated static func makeID(
        latitude: Double,
        longitude: Double,
        label: String
    ) -> String {
        String(format: "%.5f,%.5f|%@", latitude, longitude, label)
    }
}
