import CryptoKit
import Foundation
import Testing
@testable import Parkking

@Suite("Parking data contract")
@MainActor
struct ParkingDataContractTests {
    @Test("Manifest matches pinned snapshot provenance")
    func manifestMatchesPinnedValues() throws {
        let manifest = try ParkingDataManifest.load(from: .main)
        #expect(manifest.scheduleSchemaVersion == 1)
        #expect(manifest.featureCount == 21_433)
        #expect(manifest.byteSize == 15_870_101)
        #expect(manifest.sha256 == "d985b98cafe6a44060e0fdbd50b21adcea1ca17e6590120a1a120dd372216cc7")
        #expect(manifest.sourceRepo == "parking-pipeline")
        #expect(manifest.sourceRevision == "0a68237adf8b81d06b97717aa0883e50e0cdec99")
        #expect(manifest.filename == "final_parking_map.geojson")
    }

    @Test("Bundled GeoJSON hash, decode counts, and spatial index")
    func bundledGeoJSONContract() throws {
        let dataset = try ParkingDataStore.loadDataset(bundle: .main, validateHash: true)
        #expect(dataset.byteSize == dataset.manifest.byteSize)
        #expect(dataset.sha256 == dataset.manifest.sha256)
        #expect(dataset.features.count == 21_424)
        #expect(dataset.skippedPoints == 9)
        #expect(dataset.features.count + dataset.skippedPoints == dataset.manifest.featureCount)
        #expect(dataset.index.features.count == dataset.features.count)

        let ids = Set(dataset.features.map(\.id.rawValue))
        #expect(ids.count == dataset.features.count)

        if let first = dataset.features.first {
            let key = first.ruleKey.rawValue
            #expect(key.split(separator: "|", omittingEmptySubsequences: false).count == 5)
        }
    }

    @Test("Sample fixture skips Points and builds an index")
    func sampleFixtureDecode() throws {
        let url = try #require(sampleFixtureURL())
        let data = try Data(contentsOf: url)
        let decoded = try ParkingGeoJSONDecoder.decode(data)
        #expect(decoded.skippedPoints == 1)
        #expect(decoded.features.count == 4)
        let index = ParkingSpatialIndex(
            collection: ParkingFeatureCollection(features: decoded.features)
        )
        #expect(index.features.count == 4)
    }

    @Test("Decoder tolerates maxMinutes Double and disjoint_block string")
    func tolerantPropertyDecoding() throws {
        let json = """
        {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "properties": {
                "Highway": "Test St",
                "Rule": "Anytime",
                "schedule_category": "no_parking",
                "Side": "North",
                "max": null,
                "maxMinutes": 60.0,
                "disjoint_block": "block-1",
                "schedule": { "v": 1, "status": "anytime", "source": "Anytime", "windows": [] }
              },
              "geometry": {
                "type": "LineString",
                "coordinates": [[-79.38, 43.65], [-79.381, 43.651]]
              }
            },
            {
              "type": "Feature",
              "properties": {
                "Highway": "Point St",
                "Rule": "Anytime",
                "schedule_category": "no_parking",
                "Side": "East",
                "max": null,
                "maxMinutes": null,
                "schedule": null,
                "disjoint_block": null
              },
              "geometry": { "type": "Point", "coordinates": [-79.38, 43.65] }
            }
          ]
        }
        """.data(using: .utf8)!

        let decoded = try ParkingGeoJSONDecoder.decode(json)
        #expect(decoded.features.count == 1)
        #expect(decoded.skippedPoints == 1)
        #expect(decoded.features[0].properties.maxMinutes == 60)
        #expect(decoded.features[0].properties.disjointBlock == true)
        #expect(decoded.features[0].id.rawValue == 0)
    }

    private func sampleFixtureURL() -> URL? {
        let candidates = [
            Bundle(for: BundleToken.self).url(
                forResource: "sample_parking_map",
                withExtension: "geojson",
                subdirectory: "Fixtures"
            ),
            Bundle(for: BundleToken.self).url(
                forResource: "sample_parking_map",
                withExtension: "geojson"
            ),
        ]
        return candidates.compactMap { $0 }.first
    }
}

private final class BundleToken {}
