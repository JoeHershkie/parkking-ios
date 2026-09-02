import CoreLocation
import MapKit
import Testing
@testable import Parkking

@MainActor
@Suite("MapKit search coverage")
struct MapKitSearchClientTests {
    @Test("search configuration requires the Toronto coverage region")
    func searchUsesRequiredTorontoRegion() {
        let completer = MKLocalSearchCompleter()
        MapKitSearchConfiguration.apply(to: completer)
        if #available(iOS 18.0, *) {
            #expect(completer.regionPriority == .required)
        }
        #expect(completer.resultTypes.contains(.address))
        #expect(completer.resultTypes.contains(.pointOfInterest))
        #expect(
            ParkingMapConstants.contains(completer.region.center)
        )

        let request = MKLocalSearch.Request()
        MapKitSearchConfiguration.apply(to: request)
        if #available(iOS 18.0, *) {
            #expect(request.regionPriority == .required)
        }
        #expect(request.resultTypes.contains(.address))
        #expect(request.resultTypes.contains(.pointOfInterest))
    }

    @Test("final coordinate validation accepts Toronto and rejects out-of-coverage")
    func validatesFinalCoordinate() throws {
        let toronto = try MapKitSearchConfiguration.validatedCoordinate(
            ParkingMapTestFixtures.toronto
        )
        #expect(abs(toronto.latitude - 43.65) < 0.0001)

        #expect(throws: MapKitSearchError.outOfCoverage) {
            try MapKitSearchConfiguration.validatedCoordinate(ParkingMapTestFixtures.vancouver)
        }
        #expect(ParkingMapConstants.contains(ParkingMapTestFixtures.toronto))
        #expect(ParkingMapConstants.contains(ParkingMapTestFixtures.vancouver) == false)
    }

    @Test("ResolvedPlace models title and optional subtitle")
    func resolvedPlaceModel() {
        let placeWithSubtitle = ResolvedPlace(
            title: "Nathan Phillips Square",
            subtitle: "100 Queen St W, Toronto, ON",
            coordinate: ParkingMapTestFixtures.toronto
        )
        #expect(placeWithSubtitle.title == "Nathan Phillips Square")
        #expect(placeWithSubtitle.label == "Nathan Phillips Square")
        #expect(placeWithSubtitle.subtitle == "100 Queen St W, Toronto, ON")

        let placeWithoutSubtitle = ResolvedPlace(
            label: "Queen St W",
            coordinate: ParkingMapTestFixtures.toronto
        )
        #expect(placeWithoutSubtitle.title == "Queen St W")
        #expect(placeWithoutSubtitle.label == "Queen St W")
        #expect(placeWithoutSubtitle.subtitle == nil)
    }
}
