import CoreLocation
import Testing
@testable import Parkking

@Suite("Directions Launcher")
struct DirectionsLauncherTests {
    @Test("all navigation apps have valid titles and icons")
    func navigationAppMetadata() {
        #expect(NavigationApp.allCases.count == 3)
        #expect(NavigationApp.appleMaps.rawValue == "Apple Maps")
        #expect(NavigationApp.googleMaps.rawValue == "Google Maps")
        #expect(NavigationApp.waze.rawValue == "Waze")
        #expect(!NavigationApp.appleMaps.iconName.isEmpty)
        #expect(!NavigationApp.googleMaps.iconName.isEmpty)
        #expect(!NavigationApp.waze.iconName.isEmpty)
    }

    @Test("open URL uses address query when specific address is available")
    func openURLWithAddress() {
        let coord = CLLocationCoordinate2D(latitude: 43.6532, longitude: -79.3832)
        var openedURLs: [URL] = []

        NavigationApp.googleMaps.open(coordinate: coord, name: "12 Barse St", openURL: { openedURLs.append($0) })
        #expect(!openedURLs.isEmpty)
        #expect(openedURLs.first?.absoluteString.contains("12%20Barse%20St") == true)

        openedURLs.removeAll()
        NavigationApp.waze.open(coordinate: coord, name: "12 Barse St", openURL: { openedURLs.append($0) })
        #expect(!openedURLs.isEmpty)
        #expect(openedURLs.first?.absoluteString.contains("q=12%20Barse%20St") == true)
    }

    @Test("open URL falls back to coordinates when specific address is unavailable")
    func openURLWithCoordinateFallback() {
        let coord = CLLocationCoordinate2D(latitude: 43.6532, longitude: -79.3832)
        var openedURLs: [URL] = []

        NavigationApp.googleMaps.open(coordinate: coord, name: "Selected location", openURL: { openedURLs.append($0) })
        #expect(!openedURLs.isEmpty)
        #expect(openedURLs.first?.absoluteString.contains("43.6532,-79.3832") == true)

        openedURLs.removeAll()
        NavigationApp.waze.open(coordinate: coord, name: nil, openURL: { openedURLs.append($0) })
        #expect(!openedURLs.isEmpty)
        #expect(openedURLs.first?.absoluteString.contains("ll=43.6532,-79.3832") == true)
    }
}
