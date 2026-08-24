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
        id: Int,
        sourceID: String? = nil,
        sideMode: String? = nil
    ) -> ParkingFeature {
        ParkingFeature(
            id: FeatureID.fromSourceID(sourceID, index: id),
            geometry: .lineString(coordinates: coords),
            properties: ParkingProperties(
                highway: street,
                rule: rule,
                scheduleCategory: "no_parking",
                side: side,
                max: nil,
                sourceID: sourceID,
                sideMode: sideMode
            )
        )
    }

    private func multiLine(
        street: String,
        side: String,
        parts: [[[Double]]],
        rule: String = "rule",
        id: Int,
        sourceID: String? = nil,
        sideMode: String? = nil
    ) -> ParkingFeature {
        ParkingFeature(
            id: FeatureID.fromSourceID(sourceID, index: id),
            geometry: .multiLineString(coordinates: parts),
            properties: ParkingProperties(
                highway: street,
                rule: rule,
                scheduleCategory: "no_parking",
                side: side,
                max: nil,
                sourceID: sourceID,
                sideMode: sideMode
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

        let radius = CurbSelection.tapMaxDistanceMeters
        let candidates = CurbSelection.findNearestCurbCandidates(
            features: [nearNorth, nearSouth, farSameStreet],
            point: LngLat(lng: -79.4005, lat: 43.65005),
            maxDistanceMeters: radius
        )
        #expect(candidates.count >= 2)
        #expect(candidates[0].street == "Queen St")
        #expect(candidates.allSatisfy { $0.distanceMeters <= radius })
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
            localClusterMeters: CurbSelection.localClusterMeters
        )
        let north = groups.first { $0.sideDisplay.contains("North") }
        #expect(north != nil)
        // Far segment on same street/side should not join the local cluster.
        #expect(north!.features.contains { $0.properties.rule == "far rule" } == false)
    }

    @Test("highlight IDs include only the nearest clustered feature")
    func highlightIDsAreNearestFeatureOnly() {
        let closer = line(
            street: "Shallmar Blvd",
            side: "North",
            coords: [[-79.4, 43.65], [-79.4005, 43.65]],
            rule: "closer",
            id: 0,
            sourceID: "3528"
        )
        let adjacent = line(
            street: "Shallmar Blvd",
            side: "North",
            coords: [[-79.4005, 43.65], [-79.401, 43.65]],
            rule: "adjacent",
            id: 1,
            sourceID: "14704"
        )
        let result = CurbSelection.selectNearestCurb(
            features: [closer, adjacent],
            point: LngLat(lng: -79.4001, lat: 43.65002)
        )
        #expect(result.selected?.featureIDs.count == 2)
        #expect(result.selected?.highlightFeatureIDs == [closer.id])
        #expect(result.selected?.verdictFeatures.map(\.id) == [closer.id])
        #expect(result.selected?.features.count == 2)
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

    @Test("tapping nearer Both MLS part selects parent _id as one rule")
    func tappingNearerBothPartSelectsParentID() {
        let both = multiLine(
            street: "Both St",
            side: "Both",
            parts: [
                [[-79.4010, 43.6500], [-79.4010, 43.6508]],
                [[-79.40088, 43.6500], [-79.40088, 43.6508]],
            ],
            rule: "both rule",
            id: 0,
            sourceID: "9002",
            sideMode: "multi"
        )
        let west = line(
            street: "West St",
            side: "West",
            coords: [[-79.4025, 43.6500], [-79.4025, 43.6508]],
            rule: "west rule",
            id: 1,
            sourceID: "9001",
            sideMode: "single"
        )

        let tap = LngLat(lng: -79.40090, lat: 43.6504)
        let result = CurbSelection.selectNearestCurb(
            features: [both, west],
            point: tap
        )
        #expect(result.selected?.featureIDs == [FeatureID("9002")])
        #expect(result.selected?.featureKeys == ["9002"])
        #expect(result.selected?.features.count == 1)
        #expect(result.selected?.side == "Both")
        #expect(CurbGeometry.lineParts(both.geometry).count == 2)
    }

    @Test("disjoint MLS clusters using nearest part, not part 0 midpoint")
    func disjointMLSClustersUsingNearestPart() {
        let near = line(
            street: "Queen St",
            side: "North",
            coords: [[-79.4000, 43.6500], [-79.4008, 43.6500]],
            rule: "near rule",
            id: 0,
            sourceID: "near"
        )
        let disjoint = multiLine(
            street: "Queen St",
            side: "North",
            parts: [
                [[-79.4200, 43.6600], [-79.4208, 43.6600]],
                [[-79.4001, 43.65005], [-79.4007, 43.65005]],
            ],
            rule: "disjoint rule",
            id: 1,
            sourceID: "disjoint"
        )

        let candidates = CurbSelection.findNearestCurbCandidates(
            features: [near, disjoint],
            point: LngLat(lng: -79.4004, lat: 43.65002),
            maxDistanceMeters: 80
        )
        let groups = CurbSelection.groupLocalCurbSides(
            candidates: candidates,
            localClusterMeters: CurbSelection.localClusterMeters
        )
        #expect(groups.count == 1)
        #expect(groups[0].features.contains { $0.id.rawValue == "disjoint" })
        #expect(CurbGeometry.geometryMidpoint(disjoint.geometry)?.lat ?? 0 > 43.655)
        #expect(
            CurbGeometry.minDistanceBetweenGeometriesMeters(near.geometry, disjoint.geometry)
                < CurbSelection.localClusterMeters
        )
    }
}
