import CoreLocation
import Foundation

nonisolated enum CurbOverlapResolver {
    /// Overlap precedence score:
    /// 50: Active No Stopping (Red - highest priority safety/transit restriction)
    /// 40: Active No Standing (Red - high priority safety/transit restriction)
    /// 30: Active Permitted Window (Green - permitted parking window overrides general No Parking)
    /// 20: Active No Parking / Expired Window (Red - general parking prohibition)
    /// 10: Uncertain / Partial (Orange - unparsed, partial, or unknown)
    /// 0: Inactive Prohibition (Green - prohibition is inactive outside restricted hours)
    nonisolated static func precedenceScore(
        polarity: FilterPolarity,
        category: String,
        unparsed: Bool,
        severity: Int
    ) -> Int {
        if polarity == .restricted {
            if category == "no_stopping" { return 50 }
            if category == "no_standing" { return 40 }
            if category == "snow_route" || category == "snow_streetcar" || category == "winter_maintenance" { return 45 }
        }
        if polarity == .permitted && category == "restricted_periods" {
            return 30
        }
        if polarity == .restricted || polarity == .notPermitted || severity == 2 {
            return 20
        }
        if polarity == .unknown || polarity == .partial || unparsed || severity == 1 {
            return 10
        }
        return 0
    }

    nonisolated static func precedenceScore(feature: ParkingFeature) -> Int {
        let polarity: FilterPolarity
        if let p = feature.properties.polarity {
            polarity = p
        } else {
            let cat = feature.properties.scheduleCategory
            if cat == "no_stopping" || cat == "no_standing" || cat == "no_parking" {
                polarity = .restricted
            } else if cat == "restricted_periods" {
                polarity = .permitted
            } else {
                polarity = .unknown
            }
        }
        let unparsed = feature.properties.unparsed ?? false
        let severity = feature.properties.severity ?? ParkingSpatialIndex.severityOrder(polarity: polarity, unparsed: unparsed)
        return precedenceScore(
            polarity: polarity,
            category: feature.properties.scheduleCategory,
            unparsed: unparsed,
            severity: severity
        )
    }

    /// Resolves spatial overlaps between bylaw features on the same curb side.
    /// Higher precedence features clip overlapping intervals out of lower precedence features.
    nonisolated static func resolveViewportOverlaps(
        features: [ParkingFeature],
        overlapToleranceMeters: Double = 4.0
    ) -> [ParkingMapRenderItem] {
        guard !features.isEmpty else { return [] }

        // 1. Group features by street & side
        var byGroup: [String: [ParkingFeature]] = [:]
        for feature in features {
            let key = SideNormalization.curbGroupKey(
                street: feature.properties.highway,
                side: feature.properties.side
            )
            byGroup[key, default: []].append(feature)
        }

        var allRenderItems: [ParkingMapRenderItem] = []

        for (_, groupFeatures) in byGroup {
            if groupFeatures.count == 1 {
                let feature = groupFeatures[0]
                allRenderItems.append(contentsOf: makeRenderItems(for: feature))
                continue
            }

            // 2. Sort features by precedence descending (highest score first)
            let scored = groupFeatures.map { (feature: $0, score: precedenceScore(feature: $0)) }
            let sorted = scored.sorted { a, b in
                if a.score != b.score {
                    return a.score > b.score
                }
                return a.feature.id.rawValue < b.feature.id.rawValue
            }

            // 3. For each feature, compute blocked intervals from higher/equal precedence features
            for i in 0..<sorted.count {
                let current = sorted[i]
                let currentParts = CurbGeometry.lineParts(current.feature.geometry)
                let polarity = current.feature.properties.polarity ?? .unknown
                let unparsed = current.feature.properties.unparsed ?? false
                let severity = current.feature.properties.severity ?? ParkingSpatialIndex.severityOrder(polarity: polarity, unparsed: unparsed)
                let uncertain = current.feature.properties.hasUncertainCurbPlacement

                var featurePartIndex = 0

                for partCoords in currentParts {
                    guard partCoords.count >= 2 else { continue }
                    let partLength = CurbGeometry.polylineLengthMeters(partCoords)
                    guard partLength >= 1.5 else { continue }

                    var blockedRanges: [(start: Double, end: Double)] = []

                    // Check against all higher-priority features in this group
                    for j in 0..<i {
                        let higher = sorted[j]
                        let higherParts = CurbGeometry.lineParts(higher.feature.geometry)

                        for hPart in higherParts {
                            guard hPart.count >= 2 else { continue }
                            if let overlapRange = findOverlapRange(
                                targetCoords: partCoords,
                                targetLength: partLength,
                                otherCoords: hPart,
                                toleranceMeters: overlapToleranceMeters
                            ) {
                                blockedRanges.append(overlapRange)
                            }
                        }
                    }

                    if blockedRanges.isEmpty {
                        let coords: [CLLocationCoordinate2D] = partCoords.compactMap { pair in
                            guard pair.count >= 2 else { return nil }
                            return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
                        }
                        if coords.count >= 2 {
                            allRenderItems.append(
                                ParkingMapRenderItem(
                                    featureID: current.feature.id,
                                    partIndex: featurePartIndex,
                                    coordinates: coords,
                                    severity: severity,
                                    polarity: polarity,
                                    isSelected: false,
                                    isUncertainPlacement: uncertain
                                )
                            )
                            featurePartIndex += 1
                        }
                    } else {
                        let slicedParts = CurbGeometry.subtractIntervals(
                            coordinates: partCoords,
                            blockedRanges: blockedRanges,
                            minLengthMeters: 1.5
                        )
                        for sliced in slicedParts {
                            let coords: [CLLocationCoordinate2D] = sliced.compactMap { pair in
                                guard pair.count >= 2 else { return nil }
                                return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
                            }
                            if coords.count >= 2 {
                                allRenderItems.append(
                                    ParkingMapRenderItem(
                                        featureID: current.feature.id,
                                        partIndex: featurePartIndex,
                                        coordinates: coords,
                                        severity: severity,
                                        polarity: polarity,
                                        isSelected: false,
                                        isUncertainPlacement: uncertain
                                    )
                                )
                                featurePartIndex += 1
                            }
                        }
                    }
                }
            }
        }

        allRenderItems.sort { $0.severity < $1.severity }
        return allRenderItems
    }

    nonisolated static func findOverlapRange(
        targetCoords: [[Double]],
        targetLength: Double,
        otherCoords: [[Double]],
        toleranceMeters: Double
    ) -> (start: Double, end: Double)? {
        var minAlong = Double.infinity
        var maxAlong = -Double.infinity
        var hasMatch = false

        // 1. Project otherCoords vertices onto targetCoords
        for pt in otherCoords {
            guard pt.count >= 2 else { continue }
            let lngLat = LngLat(lng: pt[0], lat: pt[1])
            if let res = CurbGeometry.distancePointToLineStringDetailed(point: lngLat, coordinates: targetCoords) {
                if res.distanceMeters <= toleranceMeters {
                    hasMatch = true
                    if res.distanceAlongMeters < minAlong { minAlong = res.distanceAlongMeters }
                    if res.distanceAlongMeters > maxAlong { maxAlong = res.distanceAlongMeters }
                }
            }
        }

        // 2. Project targetCoords vertices onto otherCoords
        let cumulative = CurbGeometry.cumulativeLengthsMeters(targetCoords)
        for i in 0..<targetCoords.count {
            let pt = targetCoords[i]
            guard pt.count >= 2 else { continue }
            let lngLat = LngLat(lng: pt[0], lat: pt[1])
            if let res = CurbGeometry.distancePointToLineStringDetailed(point: lngLat, coordinates: otherCoords) {
                if res.distanceMeters <= toleranceMeters {
                    hasMatch = true
                    let along = cumulative[i]
                    if along < minAlong { minAlong = along }
                    if along > maxAlong { maxAlong = along }
                }
            }
        }

        guard hasMatch, minAlong.isFinite, maxAlong.isFinite, maxAlong > minAlong else {
            return nil
        }

        let start = max(0.0, minAlong)
        let end = min(targetLength, maxAlong)
        return (end - start) >= 1.0 ? (start, end) : nil
    }

    nonisolated private static func makeRenderItems(for feature: ParkingFeature) -> [ParkingMapRenderItem] {
        let polarity = feature.properties.polarity ?? .unknown
        let unparsed = feature.properties.unparsed ?? false
        let severity = feature.properties.severity ?? ParkingSpatialIndex.severityOrder(polarity: polarity, unparsed: unparsed)
        let uncertain = feature.properties.hasUncertainCurbPlacement

        var items: [ParkingMapRenderItem] = []
        for (partIndex, coords) in feature.coordinateParts.enumerated() {
            guard coords.count >= 2 else { continue }
            items.append(
                ParkingMapRenderItem(
                    featureID: feature.id,
                    partIndex: partIndex,
                    coordinates: coords,
                    severity: severity,
                    polarity: polarity,
                    isSelected: false,
                    isUncertainPlacement: uncertain
                )
            )
        }
        return items
    }
}
