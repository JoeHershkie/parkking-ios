import Foundation

/// Provenance metadata for the bundled Toronto curb GeoJSON snapshot.
struct ParkingDataManifest: Sendable, Codable, Equatable {
    var scheduleSchemaVersion: Int
    var featureCount: Int
    var byteSize: Int
    var sha256: String
    var sourceRepo: String
    var sourceRevision: String
    var filename: String

    nonisolated static let bundled = ParkingDataManifest(
        scheduleSchemaVersion: 1,
        featureCount: 21_433,
        byteSize: 15_870_101,
        sha256: "d985b98cafe6a44060e0fdbd50b21adcea1ca17e6590120a1a120dd372216cc7",
        sourceRepo: "parking-pipeline",
        sourceRevision: "0a68237adf8b81d06b97717aa0883e50e0cdec99",
        filename: "final_parking_map.geojson"
    )

    nonisolated static func load(from bundle: Bundle = .main) throws -> ParkingDataManifest {
        if let url = bundle.url(
            forResource: "parking-data-manifest",
            withExtension: "json",
            subdirectory: "Data"
        ) ?? bundle.url(forResource: "parking-data-manifest", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let manifest = try? JSONDecoder().decode(ParkingDataManifest.self, from: data)
        {
            return manifest
        }
        return .bundled
    }
}
