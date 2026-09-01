import CoreLocation
import MapKit
import SwiftUI
import UIKit

enum NavigationApp: String, CaseIterable, Identifiable, Sendable {
    case appleMaps = "Apple Maps"
    case googleMaps = "Google Maps"
    case waze = "Waze"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .appleMaps:
            return "map.fill"
        case .googleMaps:
            return "g.circle.fill"
        case .waze:
            return "car.fill"
        }
    }

    func open(
        coordinate: CLLocationCoordinate2D,
        name: String?,
        openURL: (URL) -> Void = { UIApplication.shared.open($0) }
    ) {
        let lat = coordinate.latitude
        let lng = coordinate.longitude
        let (query, isSpecificAddress) = Self.destinationQuery(coordinate: coordinate, name: name)
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "\(lat),\(lng)"

        switch self {
        case .appleMaps:
            let mapItem = MKMapItem(location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude), address: nil)
            mapItem.name = name ?? "Parking destination"
            mapItem.openInMaps(launchOptions: [
                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
            ])

        case .googleMaps:
            let appURL = URL(string: "comgooglemaps://?daddr=\(encodedQuery)&directionsmode=driving")
            let webURL = URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(encodedQuery)")!

            if let appURL, UIApplication.shared.canOpenURL(appURL) {
                openURL(appURL)
            } else {
                openURL(webURL)
            }

        case .waze:
            let appURLString = isSpecificAddress
                ? "waze://?q=\(encodedQuery)&navigate=yes"
                : "waze://?ll=\(lat),\(lng)&navigate=yes"
            let webURLString = isSpecificAddress
                ? "https://waze.com/ul?q=\(encodedQuery)&navigate=yes"
                : "https://waze.com/ul?ll=\(lat),\(lng)&navigate=yes"

            let appURL = URL(string: appURLString)
            let webURL = URL(string: webURLString)!

            if let appURL, UIApplication.shared.canOpenURL(appURL) {
                openURL(appURL)
            } else {
                openURL(webURL)
            }
        }
    }

    nonisolated static func destinationQuery(coordinate: CLLocationCoordinate2D, name: String?) -> (query: String, isSpecificAddress: Bool) {
        guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty,
              name != "Selected location",
              name != "Current location",
              !name.contains("°") else {
            return ("\(coordinate.latitude),\(coordinate.longitude)", false)
        }

        let lower = name.lowercased()
        if !lower.contains("toronto") && !lower.contains("on") && !lower.contains("ontario") {
            return ("\(name), Toronto, ON", true)
        }
        return (name, true)
    }
}

struct DirectionsMenuButton: View {
    var coordinate: CLLocationCoordinate2D?
    var name: String?

    var body: some View {
        Menu {
            ForEach(NavigationApp.allCases) { app in
                Button {
                    guard let coordinate else { return }
                    app.open(coordinate: coordinate, name: name)
                } label: {
                    Label(app.rawValue, systemImage: app.iconName)
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.system(size: 12, weight: .bold))
                Text("Directions")
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.accentColor.opacity(0.15), in: Capsule(style: .continuous))
            .foregroundStyle(Color.accentColor)
        }
        .accessibilityLabel("Get directions")
        .accessibilityHint("Choose maps app for driving directions")
    }
}
