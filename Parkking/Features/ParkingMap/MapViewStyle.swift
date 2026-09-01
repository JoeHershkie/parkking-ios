import Foundation
import MapKit

enum MapViewStyle: String, CaseIterable, Identifiable, Sendable, Codable {
    case standard = "standard"
    case driving = "driving"
    case transit = "transit"
    case satellite = "satellite"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard:
            return "Explore"
        case .driving:
            return "Driving"
        case .transit:
            return "Transit"
        case .satellite:
            return "3D Satellite"
        }
    }

    var iconName: String {
        switch self {
        case .standard:
            return "map"
        case .driving:
            return "car.fill"
        case .transit:
            return "tram.fill"
        case .satellite:
            return "globe.americas.fill"
        }
    }

    func makeConfiguration() -> MKMapConfiguration {
        switch self {
        case .standard:
            let config = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .default)
            config.pointOfInterestFilter = .excludingAll
            config.showsTraffic = false
            return config

        case .driving:
            let config = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .default)
            config.pointOfInterestFilter = .excludingAll
            config.showsTraffic = true
            return config

        case .transit:
            let config = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .default)
            config.pointOfInterestFilter = MKPointOfInterestFilter(including: [
                .publicTransport,
                .airport,
                .evCharger,
            ])
            config.showsTraffic = false
            return config

        case .satellite:
            let config = MKHybridMapConfiguration(elevationStyle: .realistic)
            config.pointOfInterestFilter = .excludingAll
            config.showsTraffic = false
            return config
        }
    }
}
