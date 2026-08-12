import CryptoKit
import Foundation

enum ParkingDataLoadState: Sendable, Equatable {
    case idle
    case loading
    case loaded(featureCount: Int, lineFeatureCount: Int, skippedPoints: Int)
    case failed(String)
}

struct ParkingDataset: Sendable {
    var features: [ParkingFeature]
    var index: ParkingSpatialIndex
    var skippedPoints: Int
    var manifest: ParkingDataManifest
    var byteSize: Int
    var sha256: String
}

enum ParkingDataError: LocalizedError, Sendable, Equatable {
    case missingResource(String)
    case hashMismatch(expected: String, actual: String)
    case decodeFailed(String)

    nonisolated var errorDescription: String? {
        switch self {
        case .missingResource(let name):
            return "Missing map data resource: \(name)"
        case .hashMismatch(let expected, let actual):
            return "Map data hash mismatch. Expected \(expected), got \(actual)."
        case .decodeFailed(let message):
            return "Failed to decode map data: \(message)"
        }
    }
}

/// Loads the bundled GeoJSON off the main actor, optionally validates SHA-256,
/// builds the spatial index, and publishes load state.
actor ParkingDataStore {
    private(set) var state: ParkingDataLoadState = .idle
    private(set) var dataset: ParkingDataset?

    func loadBundled(
        bundle: Bundle = .main,
        validateHash: Bool = true
    ) async throws -> ParkingDataset {
        state = .loading
        do {
            let loaded = try Self.loadDataset(bundle: bundle, validateHash: validateHash)
            dataset = loaded
            state = .loaded(
                featureCount: loaded.features.count + loaded.skippedPoints,
                lineFeatureCount: loaded.features.count,
                skippedPoints: loaded.skippedPoints
            )
            return loaded
        } catch {
            state = .failed(error.localizedDescription)
            throw error
        }
    }

    nonisolated static func loadDataset(
        bundle: Bundle,
        validateHash: Bool
    ) throws -> ParkingDataset {
        let manifest = try ParkingDataManifest.load(from: bundle)
        let url = try resourceURL(named: manifest.filename, bundle: bundle)
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()

        if validateHash, digest != manifest.sha256 {
            throw ParkingDataError.hashMismatch(expected: manifest.sha256, actual: digest)
        }

        let decoded = try ParkingGeoJSONDecoder.decode(data)
        let collection = ParkingFeatureCollection(features: decoded.features)
        let index = ParkingSpatialIndex(collection: collection)
        return ParkingDataset(
            features: decoded.features,
            index: index,
            skippedPoints: decoded.skippedPoints,
            manifest: manifest,
            byteSize: data.count,
            sha256: digest
        )
    }

    nonisolated private static func resourceURL(named name: String, bundle: Bundle) throws -> URL {
        let ns = name as NSString
        let base = ns.deletingPathExtension
        let ext = ns.pathExtension
        if let url = bundle.url(forResource: base, withExtension: ext, subdirectory: "Data") {
            return url
        }
        if let url = bundle.url(forResource: base, withExtension: ext) {
            return url
        }
        throw ParkingDataError.missingResource(name)
    }
}
