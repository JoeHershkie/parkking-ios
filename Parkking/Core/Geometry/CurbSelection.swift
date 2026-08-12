import Foundation

struct CurbCandidate: Sendable, Equatable {
    var feature: ParkingFeature
    var featureKey: String
    var distanceMeters: Double
    var street: String
    var side: String
    var sideDisplay: String
    var groupKey: String

    nonisolated init(
        feature: ParkingFeature,
        featureKey: String,
        distanceMeters: Double,
        street: String,
        side: String,
        sideDisplay: String,
        groupKey: String
    ) {
        self.feature = feature
        self.featureKey = featureKey
        self.distanceMeters = distanceMeters
        self.street = street
        self.side = side
        self.sideDisplay = sideDisplay
        self.groupKey = groupKey
    }
}

struct CurbSideGroup: Sendable, Equatable, Identifiable {
    var id: String { groupKey }
    var groupKey: String
    var street: String
    var side: String
    var sideDisplay: String
    var features: [ParkingFeature]
    var featureKeys: [String]
    var featureIDs: [FeatureID]
    var nearestDistanceMeters: Double

    nonisolated init(
        groupKey: String,
        street: String,
        side: String,
        sideDisplay: String,
        features: [ParkingFeature],
        featureKeys: [String],
        featureIDs: [FeatureID],
        nearestDistanceMeters: Double
    ) {
        self.groupKey = groupKey
        self.street = street
        self.side = side
        self.sideDisplay = sideDisplay
        self.features = features
        self.featureKeys = featureKeys
        self.featureIDs = featureIDs
        self.nearestDistanceMeters = nearestDistanceMeters
    }
}

struct SelectionResult: Sendable, Equatable {
    var groups: [CurbSideGroup]
    var selectedGroupKey: String?
    var selected: CurbSideGroup?

    nonisolated init(
        groups: [CurbSideGroup],
        selectedGroupKey: String?,
        selected: CurbSideGroup?
    ) {
        self.groups = groups
        self.selectedGroupKey = selectedGroupKey
        self.selected = selected
    }
}

enum CurbSelection {
    nonisolated static func findNearestCurbCandidates(
        features: [ParkingFeature],
        point: LngLat,
        maxDistanceMeters: Double = 80,
        maxCandidates: Int = 40
    ) -> [CurbCandidate] {
        var scored: [CurbCandidate] = []
        for feature in features {
            let distanceMeters = CurbGeometry.distancePointToFeatureMeters(
                point: point,
                feature: feature
            )
            if distanceMeters > maxDistanceMeters { continue }
            let street = SideNormalization.normalizeStreet(feature.properties.highway)
            let side = feature.properties.side
            let sideNorm = SideNormalization.normalizeSide(side)
            scored.append(
                CurbCandidate(
                    feature: feature,
                    featureKey: ParkingLabels.ruleFeatureKey(feature.properties),
                    distanceMeters: distanceMeters,
                    street: street,
                    side: side,
                    sideDisplay: SideNormalization.formatSideLabel(side),
                    groupKey: SideNormalization.curbGroupKey(street: street, side: sideNorm)
                )
            )
        }
        scored.sort { $0.distanceMeters < $1.distanceMeters }
        return Array(scored.prefix(maxCandidates))
    }

    nonisolated static func groupLocalCurbSides(
        candidates: [CurbCandidate],
        localClusterMeters: Double = 120
    ) -> [CurbSideGroup] {
        guard !candidates.isEmpty else { return [] }

        var byGroup: [String: [CurbCandidate]] = [:]
        for c in candidates {
            byGroup[c.groupKey, default: []].append(c)
        }

        var groups: [CurbSideGroup] = []
        for (_, members) in byGroup {
            let sorted = members.sorted { $0.distanceMeters < $1.distanceMeters }
            guard let nearest = sorted.first else { continue }
            let clustered = sorted.filter {
                featureLocalTo($0.feature, nearest.feature, maxMeters: localClusterMeters)
            }
            let use = clustered.isEmpty ? [nearest] : clustered

            var seen = Set<String>()
            var deduped: [ParkingFeature] = []
            var keys: [String] = []
            var ids: [FeatureID] = []
            // Keep all geometry IDs for highlight, but dedupe rules by key for verdict details.
            var geometryIDs: [FeatureID] = []
            var geometrySeen = Set<Int>()
            for m in use {
                if !geometrySeen.contains(m.feature.id.rawValue) {
                    geometrySeen.insert(m.feature.id.rawValue)
                    geometryIDs.append(m.feature.id)
                }
                let key = m.featureKey
                if seen.contains(key) { continue }
                seen.insert(key)
                deduped.append(m.feature)
                keys.append(key)
                ids.append(m.feature.id)
            }

            groups.append(
                CurbSideGroup(
                    groupKey: nearest.groupKey,
                    street: nearest.street,
                    side: nearest.side,
                    sideDisplay: nearest.sideDisplay,
                    features: deduped,
                    featureKeys: keys,
                    featureIDs: geometryIDs,
                    nearestDistanceMeters: nearest.distanceMeters
                )
            )
        }

        groups.sort { $0.nearestDistanceMeters < $1.nearestDistanceMeters }
        return groups
    }

    nonisolated private static func featureLocalTo(
        _ a: ParkingFeature,
        _ b: ParkingFeature,
        maxMeters: Double
    ) -> Bool {
        guard let midA = CurbGeometry.geometryMidpoint(a.geometry),
              let midB = CurbGeometry.geometryMidpoint(b.geometry)
        else { return false }
        return CurbGeometry.haversineMeters(midA, midB) <= maxMeters
    }

    nonisolated static func selectNearestCurb(
        features: [ParkingFeature],
        point: LngLat,
        maxDistanceMeters: Double = 80,
        localClusterMeters: Double = 120,
        preferredGroupKey: String? = nil
    ) -> SelectionResult {
        let candidates = findNearestCurbCandidates(
            features: features,
            point: point,
            maxDistanceMeters: maxDistanceMeters
        )
        let groups = groupLocalCurbSides(
            candidates: candidates,
            localClusterMeters: localClusterMeters
        )

        guard !groups.isEmpty else {
            return SelectionResult(groups: [], selectedGroupKey: nil, selected: nil)
        }

        let selected =
            (preferredGroupKey.flatMap { key in groups.first(where: { $0.groupKey == key }) })
            ?? groups[0]

        return SelectionResult(
            groups: groups,
            selectedGroupKey: selected.groupKey,
            selected: selected
        )
    }
}
