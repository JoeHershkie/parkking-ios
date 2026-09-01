import CoreLocation
import Foundation
import Observation

@MainActor
protocol FavoritesStoring: AnyObject {
    var favorites: [SavedLocation] { get }
    func isFavorite(id: String) -> Bool
    func isFavorite(coordinate: CLLocationCoordinate2D, label: String) -> Bool
    @discardableResult
    func add(label: String, subtitle: String?, coordinate: CLLocationCoordinate2D, savedAt: Date) -> [SavedLocation]
    @discardableResult
    func remove(id: String) -> [SavedLocation]
    @discardableResult
    func toggle(label: String, subtitle: String?, coordinate: CLLocationCoordinate2D) -> Bool
    @discardableResult
    func clear() -> [SavedLocation]
}

@MainActor
extension FavoritesStoring {
    @discardableResult
    func add(label: String, coordinate: CLLocationCoordinate2D) -> [SavedLocation] {
        add(label: label, subtitle: nil, coordinate: coordinate, savedAt: Date())
    }

    @discardableResult
    func add(label: String, subtitle: String?, coordinate: CLLocationCoordinate2D) -> [SavedLocation] {
        add(label: label, subtitle: subtitle, coordinate: coordinate, savedAt: Date())
    }

    func isFavorite(coordinate: CLLocationCoordinate2D, label: String) -> Bool {
        let id = SavedLocation.makeID(latitude: coordinate.latitude, longitude: coordinate.longitude, label: label)
        return isFavorite(id: id)
    }

    @discardableResult
    func toggle(label: String, coordinate: CLLocationCoordinate2D) -> Bool {
        toggle(label: label, subtitle: nil, coordinate: coordinate)
    }
}

@MainActor
@Observable
final class FavoritesStore: FavoritesStoring {
    nonisolated static let maxFavorites = 30
    nonisolated static let defaultKey = "parkking.favorites"

    private(set) var favorites: [SavedLocation] = []

    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = FavoritesStore.defaultKey) {
        self.defaults = defaults
        self.key = key
        favorites = Self.load(from: defaults, key: key)
    }

    func isFavorite(id: String) -> Bool {
        favorites.contains { $0.id == id }
    }

    func isFavorite(coordinate: CLLocationCoordinate2D, label: String) -> Bool {
        let id = SavedLocation.makeID(latitude: coordinate.latitude, longitude: coordinate.longitude, label: label)
        return isFavorite(id: id)
    }

    @discardableResult
    func add(
        label: String,
        subtitle: String? = nil,
        coordinate: CLLocationCoordinate2D,
        savedAt: Date = Date()
    ) -> [SavedLocation] {
        let id = SavedLocation.makeID(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            label: label
        )
        let entry = SavedLocation(
            id: id,
            label: label,
            subtitle: subtitle,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            savedAt: savedAt
        )
        favorites = [entry] + favorites.filter { $0.id != id }
        if favorites.count > Self.maxFavorites {
            favorites = Array(favorites.prefix(Self.maxFavorites))
        }
        persist()
        return favorites
    }

    @discardableResult
    func remove(id: String) -> [SavedLocation] {
        favorites = favorites.filter { $0.id != id }
        persist()
        return favorites
    }

    @discardableResult
    func toggle(
        label: String,
        subtitle: String? = nil,
        coordinate: CLLocationCoordinate2D
    ) -> Bool {
        let id = SavedLocation.makeID(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            label: label
        )
        if isFavorite(id: id) {
            remove(id: id)
            return false
        } else {
            add(label: label, subtitle: subtitle, coordinate: coordinate)
            return true
        }
    }

    @discardableResult
    func clear() -> [SavedLocation] {
        favorites = []
        persist()
        return favorites
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(favorites) else { return }
        defaults.set(data, forKey: key)
    }

    nonisolated private static func load(from defaults: UserDefaults, key: String) -> [SavedLocation] {
        guard let data = defaults.data(forKey: key) else { return [] }
        if let list = try? JSONDecoder().decode([SavedLocation].self, from: data) {
            return Array(list.prefix(maxFavorites))
        }
        return []
    }
}
