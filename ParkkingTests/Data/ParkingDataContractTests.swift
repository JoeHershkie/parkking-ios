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
        #expect(manifest.featureCount == 24_669)
        #expect(manifest.byteSize == 22_355_968)
        #expect(manifest.sha256 == "2c5a9af95b0d0559d1d889964f5d9f2da1144729266e1d3b0d6da23dfacd3ece")
        #expect(manifest.artifact == "parking_map.sqlite")
        #expect(manifest.format == "sqlite3_rtree_wkb")
    }

    @Test("Bundled SQLite dataset hash, decode counts, and spatial index")
    func bundledDatasetContract() throws {
        let dataset = try ParkingDataStore.loadDataset(bundle: .main, validateHash: true)
        #expect(dataset.byteSize == dataset.manifest.byteSize)
        #expect(dataset.sha256 == dataset.manifest.sha256)
        #expect(dataset.features.count == 24_669)
        #expect(dataset.skippedPoints == 0)
        #expect(dataset.index.features.count == dataset.features.count)

        let ids = Set(dataset.features.map(\.id.rawValue))
        #expect(ids.count == dataset.features.count)
        #expect(dataset.features.allSatisfy { feature in
            guard let sourceID = feature.properties.sourceID, !sourceID.isEmpty else { return false }
            return feature.id.rawValue == sourceID
        })

        if let first = dataset.features.first {
            let key = first.ruleKey.rawValue
            #expect(key.split(separator: "|", omittingEmptySubsequences: false).count == 5)
            #expect(ParkingLabels.ruleFeatureKey(first.properties) == first.id.rawValue)
        }
    }

    @Test("Sample fixture skips Points and Polygon, keeps Both MLS parts")
    func sampleFixtureDecode() throws {
        let url = try #require(sampleFixtureURL())
        let data = try Data(contentsOf: url)
        let decoded = try ParkingGeoJSONDecoder.decode(data)
        #expect(decoded.skippedPoints == 1)
        #expect(decoded.features.count == 7)

        let west = try #require(decoded.features.first { $0.id.rawValue == "9001" })
        #expect(west.properties.side == "West")
        #expect(west.properties.sideMode == "single")
        #expect(west.geometry.typeName == "LineString")
        #expect(west.properties.curbGeometryMethod == "offset_fallback")
        #expect(west.properties.curbWarnings == ["ROAD_EDGE_LOW_COVERAGE", "CENTERLINE_FALLBACK"])
        #expect(west.properties.hasUncertainCurbPlacement)

        let both = try #require(decoded.features.first { $0.id.rawValue == "9002" })
        #expect(both.properties.side == "Both")
        #expect(both.properties.sideMode == "multi")
        guard case .multiLineString(let parts) = both.geometry else {
            Issue.record("Both feature should decode as MultiLineString, not LineString of ring 0")
            return
        }
        #expect(parts.count == 2)
        #expect(ParkingLabels.ruleFeatureKey(both.properties) == "9002")

        let stringified = try #require(decoded.features.first { $0.id.rawValue == "9003" })
        #expect(stringified.properties.sourceID == "9003")
        #expect(stringified.properties.curbWarnings == ["SIDE_AMBIGUOUS"])
        #expect(stringified.properties.centrelineIDs == [444, 445])
        #expect(stringified.properties.hasUncertainCurbPlacement)

        #expect(decoded.features.contains { $0.properties.highway == "Should Skip Polygon" } == false)

        let index = ParkingSpatialIndex(
            collection: ParkingFeatureCollection(features: decoded.features)
        )
        #expect(index.features.count == 7)
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
        #expect(decoded.features[0].id.rawValue == "idx:0")
    }

    @Test("Decoder accepts numeric or string _id and stringified curb lists")
    func tolerantCurbPropertyDecoding() throws {
        let json = """
        {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "properties": {
                "_id": 42,
                "Highway": "Numeric ID St",
                "Rule": "Anytime",
                "schedule_category": "no_parking",
                "Side": "West",
                "side_mode": "single",
                "curb_geometry_method": "offset_fallback",
                "curb_warnings": ["CENTERLINE_FALLBACK"],
                "centreline_ids": [10, 11],
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
                "_id": "43",
                "Highway": "String ID St",
                "Rule": "Anytime",
                "schedule_category": "no_parking",
                "Side": "Both",
                "side_mode": "multi",
                "curb_geometry_method": "centerline_unresolved",
                "curb_warnings": "[\\"SIDE_AMBIGUOUS\\"]",
                "centreline_ids": "[20, 21]",
                "schedule": { "v": 1, "status": "anytime", "source": "Anytime", "windows": [] }
              },
              "geometry": {
                "type": "MultiLineString",
                "coordinates": [
                  [[-79.38, 43.65], [-79.381, 43.651]],
                  [[-79.3801, 43.65], [-79.3811, 43.651]]
                ]
              }
            },
            {
              "type": "Feature",
              "properties": {
                "_id": 44,
                "Highway": "Polygon St",
                "Rule": "Anytime",
                "schedule_category": "no_parking",
                "Side": "North"
              },
              "geometry": {
                "type": "Polygon",
                "coordinates": [[[-79.38, 43.65], [-79.38, 43.651], [-79.381, 43.651], [-79.38, 43.65]]]
              }
            },
            {
              "type": "Feature",
              "properties": {
                "_id": 45,
                "Highway": "Collection St",
                "Rule": "Anytime",
                "schedule_category": "no_parking",
                "Side": "North"
              },
              "geometry": {
                "type": "GeometryCollection",
                "geometries": []
              }
            }
          ]
        }
        """.data(using: .utf8)!

        let decoded = try ParkingGeoJSONDecoder.decode(json)
        #expect(decoded.features.count == 2)
        #expect(decoded.skippedPoints == 0)
        #expect(decoded.features[0].id.rawValue == "42")
        #expect(decoded.features[0].properties.sourceID == "42")
        #expect(decoded.features[0].properties.centrelineIDs == [10, 11])
        #expect(decoded.features[1].id.rawValue == "43")
        #expect(decoded.features[1].properties.curbWarnings == ["SIDE_AMBIGUOUS"])
        #expect(decoded.features[1].properties.centrelineIDs == [20, 21])
        guard case .multiLineString(let parts) = decoded.features[1].geometry else {
            Issue.record("Expected MultiLineString with both parts")
            return
        }
        #expect(parts.count == 2)
        #expect(ParkingLabels.ruleFeatureKey(decoded.features[0].properties) == "42")
        #expect(decoded.features[0].properties.hasUncertainCurbPlacement)
        #expect(decoded.features[1].properties.hasUncertainCurbPlacement)
    }

    @Test("Schedule dictionary init matches JSONDecoder including last day-of-month")
    func scheduleDictionaryMatchesJSONDecoder() throws {
        let object: [String: Any] = [
            "v": 1,
            "status": "ok",
            "source": "Mon-Fri 8am-6pm except holidays",
            "windows": [
                [
                    "days": [1, 2, 3, 4, 5],
                    "startMinute": 480,
                    "endMinute": 1080,
                    "crossesMidnight": false,
                    "calendar": [
                        "dayOfMonthRanges": [
                            ["start": 1, "end": "last"],
                        ],
                    ],
                ],
            ],
            "flags": ["exceptPublicHolidays": true],
            "inverted": false,
            "unparsedClauses": [] as [String],
        ]
        let data = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(Schedule.self, from: data)
        let fromDictionary = try #require(Schedule(dictionary: object))
        #expect(fromDictionary == decoded)
        #expect(fromDictionary.windows[0].calendar?.dayOfMonthRanges?.first?.end == .last)
        #expect(fromDictionary.flags?.exceptPublicHolidays == true)
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
