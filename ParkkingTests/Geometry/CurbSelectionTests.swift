import Testing
@testable import Parkking

@MainActor
@Suite("CurbSelection")
struct CurbSelectionTests {
    private func line(
        street: String,
        side: String,
        coords: [[Double]],
        rule: String = "rule",
        id: Int
    ) -> ParkingFeature {
        ParkingFeature(
            id: FeatureID(id),
            geometry: .lineString(coordinates: coords),
            properties: ParkingProperties(
                highway: street,
                rule: rule,
                scheduleCategory: "no_parking",
                side: side,
                max: nil
            )
        )
    }

    @Test("finds nearest by geometric distance, not pixel radius")
    func findsNearestByGeometricDistance() {
        let nearNorth = line(
            street: "Queen St",
            side: "N",
            coords: [[-79.4, 43.65], [-79.401, 43.65]],
            rule: "north rule",
            id: 0
        )
        let nearSouth = line(
            street: "Queen St",
            side: "South",
            coords: [[-79.4, 43.6499], [-79.401, 43.6499]],
            rule: "south rule",
            id: 1
        )
        let farSameStreet = line(
            street: "Queen St",
            side: "North",
            coords: [[-79.42, 43.66], [-79.421, 43.66]],
            rule: "far rule",
            id: 2
        )

        let candidates = CurbSelection.findNearestCurbCandidates(
            features: [nearNorth, nearSouth, farSameStreet],
            point: LngLat(lng: -79.4005, lat: 43.65005),
            maxDistanceMeters: 80
        )
        #expect(candidates.count >= 2)
        #expect(candidates[0].street == "Queen St")
        #expect(candidates.allSatisfy { $0.distanceMeters <= 80 })
    }

    @Test("groups local street sides without whole-street merging")
    func groupsLocalStreetSidesWithoutWholeStreetMerging() {
        let nearNorth = line(
            street: "Queen St",
            side: "N",
            coords: [[-79.4, 43.65], [-79.401, 43.65]],
            rule: "north rule",
            id: 0
        )
        let nearSouth = line(
            street: "Queen St",
            side: "South",
            coords: [[-79.4, 43.6499], [-79.401, 43.6499]],
            rule: "south rule",
            id: 1
        )
        let farSameStreet = line(
            street: "Queen St",
            side: "North",
            coords: [[-79.42, 43.66], [-79.421, 43.66]],
            rule: "far rule",
            id: 2
        )

        let candidates = CurbSelection.findNearestCurbCandidates(
            features: [nearNorth, nearSouth, farSameStreet],
            point: LngLat(lng: -79.4005, lat: 43.65),
            maxDistanceMeters: 2000
        )
        let groups = CurbSelection.groupLocalCurbSides(
            candidates: candidates,
            localClusterMeters: 120
        )
        let north = groups.first { $0.sideDisplay.contains("North") }
        #expect(north != nil)
        // Far segment on same street/side should not join the local cluster.
        #expect(north!.features.contains { $0.properties.rule == "far rule" } == false)
    }

    @Test("auto-selects nearest group and supports preferred key")
    func autoSelectsNearestGroupAndSupportsPreferredKey() {
        let nearNorth = line(
            street: "Queen St",
            side: "N",
            coords: [[-79.4, 43.65], [-79.401, 43.65]],
            rule: "north rule",
            id: 0
        )
        let nearSouth = line(
            street: "Queen St",
            side: "South",
            coords: [[-79.4, 43.6499], [-79.401, 43.6499]],
            rule: "south rule",
            id: 1
        )

        let result = CurbSelection.selectNearestCurb(
            features: [nearNorth, nearSouth],
            point: LngLat(lng: -79.4005, lat: 43.6502)
        )
        #expect(result.selected != nil)
        #expect(result.groups.count >= 1)

        if let other = result.groups.first(where: { $0.groupKey != result.selectedGroupKey }) {
            let preferred = CurbSelection.selectNearestCurb(
                features: [nearNorth, nearSouth],
                point: LngLat(lng: -79.4005, lat: 43.6502),
                preferredGroupKey: other.groupKey
            )
            #expect(preferred.selectedGroupKey == other.groupKey)
        }
    }
}
