import CoreLocation
import Foundation
import Testing
@testable import Parkking

@MainActor
@Suite("FavoritesStore")
struct FavoritesStoreTests {
    private func makeStore() -> FavoritesStore {
        ParkingMapTestFixtures.favoritesStore()
    }

    @Test("adds, toggles, removes, and deduplicates favorites")
    func addsTogglesAndRemoves() {
        let store = makeStore()
        let coord = CLLocationCoordinate2D(latitude: 43.65, longitude: -79.38)
        #expect(store.favorites.isEmpty)
        #expect(store.isFavorite(coordinate: coord, label: "Work") == false)

        // Toggle on
        let added = store.toggle(label: "Work", subtitle: "Financial District", coordinate: coord)
        #expect(added == true)
        #expect(store.favorites.count == 1)
        #expect(store.isFavorite(coordinate: coord, label: "Work") == true)
        #expect(store.favorites.first?.subtitle == "Financial District")

        // Toggle off
        let removed = store.toggle(label: "Work", coordinate: coord)
        #expect(removed == false)
        #expect(store.favorites.isEmpty)
        #expect(store.isFavorite(coordinate: coord, label: "Work") == false)
    }

    @Test("persists across favorites store instances")
    func persistsAcrossInstances() {
        let suite = "ParkkingTests.Favorites.Persist.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let first = FavoritesStore(defaults: defaults, key: suite)
        first.add(
            label: "Home",
            subtitle: "100 Queen St W",
            coordinate: CLLocationCoordinate2D(latitude: 43.65, longitude: -79.4)
        )
        let second = FavoritesStore(defaults: defaults, key: suite)
        #expect(second.favorites.first?.label == "Home")
        #expect(second.favorites.first?.subtitle == "100 Queen St W")
        defaults.removePersistentDomain(forName: suite)
    }
}
