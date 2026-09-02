import Foundation

struct IndexedFeature: Sendable {
    var feature: ParkingFeature
    var featureKey: String
    var minLng: Double
    var minLat: Double
    var maxLng: Double
    var maxLat: Double
    var cells: [String]

    nonisolated init(
        feature: ParkingFeature,
        featureKey: String,
        minLng: Double,
        minLat: Double,
        maxLng: Double,
        maxLat: Double,
        cells: [String]
    ) {
        self.feature = feature
        self.featureKey = featureKey
        self.minLng = minLng
        self.minLat = minLat
        self.maxLng = maxLng
        self.maxLat = maxLat
        self.cells = cells
    }
}

final class ParkingSpatialIndex: @unchecked Sendable {
    nonisolated let features: [IndexedFeature]
    nonisolated private let cellDeg: Double
    nonisolated private let cells: [String: [Int]]

    nonisolated static let defaultCellDeg = 0.01

    nonisolated init(
        collection: ParkingFeatureCollection,
        cellDeg: Double = ParkingSpatialIndex.defaultCellDeg
    ) {
        self.cellDeg = cellDeg
        var features: [IndexedFeature] = []
        var cells: [String: [Int]] = [:]

        for feature in collection.features {
            guard let bbox = CurbGeometry.featureBBox(feature) else { continue }
            let index = features.count
            let featureCells = Self.cellsForBBox(bbox, cellDeg: cellDeg)
            for c in featureCells {
                cells[c, default: []].append(index)
            }
            features.append(
                IndexedFeature(
                    feature: feature,
                    featureKey: ParkingLabels.ruleFeatureKey(feature.properties),
                    minLng: bbox.minLng,
                    minLat: bbox.minLat,
                    maxLng: bbox.maxLng,
                    maxLat: bbox.maxLat,
                    cells: featureCells
                )
            )
        }

        self.features = features
        self.cells = cells
    }

    nonisolated private static func cellKey(ix: Int, iy: Int) -> String {
        "\(ix):\(iy)"
    }

    nonisolated private static func cellsForBBox(_ bbox: BBox, cellDeg: Double) -> [String] {
        let minX = Int(floor(bbox.minLng / cellDeg))
        let maxX = Int(floor(bbox.maxLng / cellDeg))
        let minY = Int(floor(bbox.minLat / cellDeg))
        let maxY = Int(floor(bbox.maxLat / cellDeg))
        var out: [String] = []
        if minX <= maxX, minY <= maxY {
            out.reserveCapacity((maxX - minX + 1) * (maxY - minY + 1))
            for ix in minX...maxX {
                for iy in minY...maxY {
                    out.append(cellKey(ix: ix, iy: iy))
                }
            }
        }
        return out
    }

    nonisolated func queryBBox(_ bbox: BBox, padDeg: Double = 0) -> [ParkingFeature] {
        let padded = BBox(
            minLng: bbox.minLng - padDeg,
            minLat: bbox.minLat - padDeg,
            maxLng: bbox.maxLng + padDeg,
            maxLat: bbox.maxLat + padDeg
        )
        let cellSet = Self.cellsForBBox(padded, cellDeg: cellDeg)
        var seen = Set<Int>()
        var out: [ParkingFeature] = []
        for c in cellSet {
            guard let idxs = cells[c] else { continue }
            for i in idxs {
                if seen.contains(i) { continue }
                seen.insert(i)
                let item = features[i]
                if item.maxLng < padded.minLng
                    || item.minLng > padded.maxLng
                    || item.maxLat < padded.minLat
                    || item.minLat > padded.maxLat
                {
                    continue
                }
                out.append(item.feature)
            }
        }
        return out
    }

    nonisolated func allFeatures() -> [ParkingFeature] {
        features.map(\.feature)
    }

    /// Higher overlay sort-key draws on top.
    /// Allowed first (0), unclear second (1), restrictions last (2).
    nonisolated static func severityOrder(
        polarity: FilterPolarity?,
        unparsed: Bool? = nil
    ) -> Int {
        if unparsed == true || polarity == .unknown || polarity == .partial { return 1 }
        if polarity == .restricted || polarity == .notPermitted { return 2 }
        return 0
    }

    nonisolated static func sortFeaturesBySeverity(
        _ features: [ParkingFeature]
    ) -> [ParkingFeature] {
        features.sorted { a, b in
            let sa = severityOrder(polarity: a.properties.polarity, unparsed: a.properties.unparsed)
            let sb = severityOrder(polarity: b.properties.polarity, unparsed: b.properties.unparsed)
            return sa < sb
        }
    }

    nonisolated static func enrichFeaturesSubset(
        _ features: [ParkingFeature],
        resolved: ResolvedTimeQuery,
        includeUnknown: Bool
    ) -> ParkingFeatureCollection {
        var enriched: [ParkingFeature] = []
        enriched.reserveCapacity(features.count)

        for feature in features {
            let evaluation = ScheduleEvaluator.evaluateQuery(
                props: feature.properties,
                query: resolved,
                includeUnknown: includeUnknown
            )
            guard evaluation.visible else { continue }
            var props = feature.properties
            let featureKey = ParkingLabels.ruleFeatureKey(props)
            props.polarity = evaluation.polarity
            props.visible = evaluation.visible
            props.unparsed = evaluation.unparsed
            props.partial = evaluation.partial
            props.failed = evaluation.failed
            props.featureKey = featureKey
            props.severity = severityOrder(
                polarity: evaluation.polarity,
                unparsed: evaluation.unparsed
            )
            enriched.append(
                ParkingFeature(
                    id: feature.id,
                    geometry: feature.geometry,
                    properties: props,
                    coordinateParts: feature.coordinateParts
                )
            )
        }

        return ParkingFeatureCollection(features: sortFeaturesBySeverity(enriched))
    }

    nonisolated static func enrichFeaturesSubset(
        _ features: [ParkingFeature],
        slot: Slot,
        includeUnknown: Bool,
        endMinuteOfDay: Int? = nil
    ) -> ParkingFeatureCollection {
        var enriched: [ParkingFeature] = []
        enriched.reserveCapacity(features.count)

        for feature in features {
            let evaluation = ScheduleEvaluator.evaluateInRange(
                props: feature.properties,
                slot: slot,
                endMinuteOfDay: endMinuteOfDay,
                includeUnknown: includeUnknown
            )
            guard evaluation.visible else { continue }
            var props = feature.properties
            let featureKey = ParkingLabels.ruleFeatureKey(props)
            props.polarity = evaluation.polarity
            props.visible = evaluation.visible
            props.unparsed = evaluation.unparsed
            props.partial = evaluation.partial
            props.failed = evaluation.failed
            props.featureKey = featureKey
            props.severity = severityOrder(
                polarity: evaluation.polarity,
                unparsed: evaluation.unparsed
            )
            enriched.append(
                ParkingFeature(
                    id: feature.id,
                    geometry: feature.geometry,
                    properties: props,
                    coordinateParts: feature.coordinateParts
                )
            )
        }

        return ParkingFeatureCollection(features: sortFeaturesBySeverity(enriched))
    }
}

/// Compatibility alias used by early call sites / tests.
typealias ParkingSpatialEnrichment = ParkingSpatialIndex
