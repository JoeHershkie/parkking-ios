import Foundation
import Testing
@testable import Parkking

@Suite("Performance gate")
struct PerformanceGateTests {
    @Test("bundled decode + index stays within rough gate")
    func bundledDecodeAndIndexTiming() throws {
        let started = ContinuousClock.now
        let dataset = try ParkingDataStore.loadDataset(bundle: .main, validateHash: true)
        let elapsed = ContinuousClock.now - started

        #expect(dataset.features.count == 21_424)
        #expect(dataset.index.allFeatures().count == 21_424)
        // Soft gate for CI/simulator; physical-device numbers go in the PR.
        #expect(elapsed < .seconds(8))
    }

    @Test("indexed tap selection stays under soft gate")
    func indexedTapSelectionTiming() throws {
        let dataset = try ParkingDataStore.loadDataset(bundle: .main, validateHash: false)
        let point = LngLat(lng: -79.38, lat: 43.65)
        let pad = CurbGeometry.degreesPad(forMeters: 80, atLatitude: point.lat)
        let started = ContinuousClock.now
        let subset = dataset.index.queryBBox(
            BBox(minLng: point.lng, minLat: point.lat, maxLng: point.lng, maxLat: point.lat),
            padDeg: pad
        )
        _ = CurbSelection.selectNearestCurb(features: subset, point: point)
        let elapsed = ContinuousClock.now - started
        #expect(elapsed < .milliseconds(50))
    }
}
