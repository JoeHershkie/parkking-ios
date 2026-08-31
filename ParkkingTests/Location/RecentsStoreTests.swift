import CoreLocation
import Foundation
import Testing
@testable import Parkking

@MainActor
@Suite("RecentsStore")
struct RecentsStoreTests {
    private func makeStore() -> RecentsStore {
        ParkingMapTestFixtures.recentsStore()
    }

    @Test("orders newest first, de-duplicates, and caps at eight")
    func ordersDedupesAndCaps() {
        let store = makeStore()
        for i in 0..<12 {
            store.add(
                label: "Place \(i)",
                coordinate: CLLocationCoordinate2D(
                    latitude: 43.65 + Double(i) * 0.001,
                    longitude: -79.38
                ),
                savedAt: Date(timeIntervalSince1970: Double(i))
            )
        }
        #expect(store.recents.count == RecentsStore.maxRecents)
        #expect(store.recents.first?.label == "Place 11")
        #expect(store.recents.last?.label == "Place 4")

        store.add(
            label: "Place 11",
            coordinate: CLLocationCoordinate2D(latitude: 43.65 + 11 * 0.001, longitude: -79.38),
            savedAt: Date(timeIntervalSince1970: 99)
        )
        #expect(store.recents.count == RecentsStore.maxRecents)
        #expect(store.recents.first?.label == "Place 11")
        #expect(store.recents.filter { $0.label == "Place 11" }.count == 1)
    }

    @Test("removes one and clears all")
    func removesAndClears() {
        let store = makeStore()
        store.add(
            label: "A",
            coordinate: CLLocationCoordinate2D(latitude: 43.65, longitude: -79.38)
        )
        let second = store.add(
            label: "B",
            coordinate: CLLocationCoordinate2D(latitude: 43.66, longitude: -79.39)
        )
        let id = second[0].id
        store.remove(id: id)
        #expect(store.recents.contains { $0.id == id } == false)
        store.clear()
        #expect(store.recents.isEmpty)
    }

    @Test("recovers from corrupt storage")
    func recoversFromCorruptStorage() {
        let suite = "ParkkingTests.Recents.Corrupt.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defaults.set("not-json", forKey: suite)
        let store = RecentsStore(defaults: defaults, key: suite)
        #expect(store.recents.isEmpty)
        store.add(
            label: "Recovered",
            coordinate: CLLocationCoordinate2D(latitude: 43.65, longitude: -79.38)
        )
        #expect(store.recents.count == 1)
        defaults.removePersistentDomain(forName: suite)
    }

    @Test("persists across store instances")
    func persistsAcrossInstances() {
        let suite = "ParkkingTests.Recents.Persist.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let first = RecentsStore(defaults: defaults, key: suite)
        first.add(
            label: "Home",
            subtitle: "100 Queen St W",
            coordinate: CLLocationCoordinate2D(latitude: 43.65, longitude: -79.4)
        )
        let second = RecentsStore(defaults: defaults, key: suite)
        #expect(second.recents.first?.label == "Home")
        #expect(second.recents.first?.subtitle == "100 Queen St W")
        defaults.removePersistentDomain(forName: suite)
    }
}
