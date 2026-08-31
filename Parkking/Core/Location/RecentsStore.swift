import CoreLocation
import Foundation
import Observation

@MainActor
protocol RecentsStoring: AnyObject {
    var recents: [SavedLocation] { get }
    @discardableResult
    func add(label: String, subtitle: String?, coordinate: CLLocationCoordinate2D, savedAt: Date) -> [SavedLocation]
    @discardableResult
    func remove(id: String) -> [SavedLocation]
    @discardableResult
    func clear() -> [SavedLocation]
}

@MainActor
extension RecentsStoring {
    @discardableResult
    func add(label: String, coordinate: CLLocationCoordinate2D, savedAt: Date) -> [SavedLocation] {
        add(label: label, subtitle: nil, coordinate: coordinate, savedAt: savedAt)
    }

    @discardableResult
    func add(label: String, coordinate: CLLocationCoordinate2D) -> [SavedLocation] {
        add(label: label, subtitle: nil, coordinate: coordinate, savedAt: Date())
    }

    @discardableResult
    func add(label: String, subtitle: String?, coordinate: CLLocationCoordinate2D) -> [SavedLocation] {
        add(label: label, subtitle: subtitle, coordinate: coordinate, savedAt: Date())
    }
}

@MainActor
@Observable
final class RecentsStore: RecentsStoring {
    nonisolated static let maxRecents = 8
    nonisolated static let defaultKey = "parkking.recents"

    private(set) var recents: [SavedLocation] = []

    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = RecentsStore.defaultKey) {
        self.defaults = defaults
        self.key = key
        recents = Self.load(from: defaults, key: key)
    }

    @discardableResult
    func add(
        label: String,
        subtitle: String? = nil,
        coordinate: CLLocationCoordinate2D,
        savedAt: Date
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
        recents = [entry] + recents.filter { $0.id != id }
        if recents.count > Self.maxRecents {
            recents = Array(recents.prefix(Self.maxRecents))
        }
        persist()
        return recents
    }

    @discardableResult
    func remove(id: String) -> [SavedLocation] {
        recents = recents.filter { $0.id != id }
        persist()
        return recents
    }

    @discardableResult
    func clear() -> [SavedLocation] {
        recents = []
        persist()
        return recents
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(recents) else { return }
        defaults.set(data, forKey: key)
    }

    nonisolated private static func load(from defaults: UserDefaults, key: String) -> [SavedLocation] {
        guard let data = defaults.data(forKey: key) else { return [] }
        if let list = try? JSONDecoder().decode([SavedLocation].self, from: data) {
            return Array(list.prefix(maxRecents))
        }
        return []
    }
}
