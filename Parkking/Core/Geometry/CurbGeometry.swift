import CoreLocation
import Foundation

struct LngLat: Sendable, Hashable, Equatable {
    var lng: Double
    var lat: Double

    nonisolated init(lng: Double, lat: Double) {
        self.lng = lng
        self.lat = lat
    }
}

struct BBox: Sendable, Hashable, Equatable {
    var minLng: Double
    var minLat: Double
    var maxLng: Double
    var maxLat: Double

    nonisolated init(minLng: Double, minLat: Double, maxLng: Double, maxLat: Double) {
        self.minLng = minLng
        self.minLat = minLat
        self.maxLng = maxLng
        self.maxLat = maxLat
    }
}

enum CurbGeometry {
    nonisolated static let earthRadiusM = 6_371_000.0

    nonisolated static func lineParts(_ geometry: ParkingGeometry) -> [[[Double]]] {
        // Returns array of line parts; each part is [[lng, lat], ...]
        switch geometry {
        case .lineString(let coordinates):
            return [coordinates]
        case .multiLineString(let coordinates):
            return coordinates
        }
    }

    /// MapKit coordinates for each line part, computed once at feature construction.
    nonisolated static func mapCoordinateParts(_ geometry: ParkingGeometry) -> [[CLLocationCoordinate2D]] {
        lineParts(geometry).compactMap { part in
            let coords: [CLLocationCoordinate2D] = part.compactMap { pair in
                guard pair.count >= 2 else { return nil }
                return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
            }
            return coords.count >= 2 ? coords : nil
        }
    }

    // Fix: lineParts should return [[lng,lat]][] i.e. [[[Double]]] is wrong naming.
    // Actually LineString coords are [[lng,lat]] so parts is [[[lng,lat]]] for multi.
    // For LineString return [coordinates] where coordinates is [[Double]].
    // So return type [[ [Double] ]] = [[[Double]]]

    nonisolated static func isLineGeometry(_ geometry: ParkingGeometry) -> Bool {
        true
    }

    nonisolated static func forEachPosition(
        _ geometry: ParkingGeometry,
        visit: (Double, Double) -> Void
    ) {
        for part in lineParts(geometry) {
            for pos in part {
                guard pos.count >= 2 else { continue }
                visit(pos[0], pos[1])
            }
        }
    }

    nonisolated static func partMidpoint(_ coordinates: [[Double]]) -> LngLat? {
        guard coordinates.count >= 2 else {
            guard let first = coordinates.first, first.count >= 2 else { return nil }
            return LngLat(lng: first[0], lat: first[1])
        }
        let totalLen = polylineLengthMeters(coordinates)
        return pointAtDistanceMeters(coordinates: coordinates, distanceMeters: totalLen / 2)
    }

    nonisolated static func geometryMidpoint(_ geometry: ParkingGeometry) -> LngLat? {
        partMidpoint(lineParts(geometry).first ?? [])
    }

    /// Midpoint of every line part (disjoint MLS uses more than part 0).
    nonisolated static func geometryPartMidpoints(_ geometry: ParkingGeometry) -> [LngLat] {
        lineParts(geometry).compactMap(partMidpoint)
    }

    /// Minimum distance between any parts of two geometries, not part 0 only.
    nonisolated static func minDistanceBetweenGeometriesMeters(
        _ a: ParkingGeometry,
        _ b: ParkingGeometry
    ) -> Double {
        let partsA = lineParts(a)
        let partsB = lineParts(b)
        guard !partsA.isEmpty, !partsB.isEmpty else { return .infinity }
        var minDist = Double.infinity
        for partA in partsA {
            guard let midA = partMidpoint(partA) else { continue }
            for partB in partsB {
                let d = distancePointToLineStringMeters(point: midA, coordinates: partB)
                if d < minDist { minDist = d }
            }
        }
        for partB in partsB {
            guard let midB = partMidpoint(partB) else { continue }
            for partA in partsA {
                let d = distancePointToLineStringMeters(point: midB, coordinates: partA)
                if d < minDist { minDist = d }
            }
        }
        return minDist
    }

    nonisolated static func featureBBox(_ feature: ParkingFeature) -> BBox? {
        var minLng = Double.infinity
        var minLat = Double.infinity
        var maxLng = -Double.infinity
        var maxLat = -Double.infinity
        forEachPosition(feature.geometry) { lng, lat in
            if lng < minLng { minLng = lng }
            if lat < minLat { minLat = lat }
            if lng > maxLng { maxLng = lng }
            if lat > maxLat { maxLat = lat }
        }
        guard minLng.isFinite else { return nil }
        return BBox(minLng: minLng, minLat: minLat, maxLng: maxLng, maxLat: maxLat)
    }

    nonisolated private static func toRad(_ deg: Double) -> Double {
        deg * .pi / 180
    }

    nonisolated static func haversineMeters(_ a: LngLat, _ b: LngLat) -> Double {
        let dLat = toRad(b.lat - a.lat)
        let dLng = toRad(b.lng - a.lng)
        let lat1 = toRad(a.lat)
        let lat2 = toRad(b.lat)
        let h =
            sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2)
        return 2 * earthRadiusM * asin(min(1, sqrt(h)))
    }

    nonisolated private static func metersPerDegree(lat: Double) -> (mx: Double, my: Double) {
        let my = (.pi / 180) * earthRadiusM
        let mx = my * cos(toRad(lat))
        return (mx: max(mx, 1e-6), my: my)
    }

    /// Degree padding that covers `meters` in both axes at `latitude`.
    nonisolated static func degreesPad(forMeters meters: Double, atLatitude latitude: Double)
        -> Double
    {
        let m = metersPerDegree(lat: latitude)
        let latPad = meters / m.my
        let lngPad = meters / m.mx
        return max(latPad, lngPad)
    }

    nonisolated private static func project(
        lng: Double,
        lat: Double,
        originLat: Double
    ) -> (x: Double, y: Double) {
        let m = metersPerDegree(lat: originLat)
        return (x: lng * m.mx, y: lat * m.my)
    }

    nonisolated private static func nearestPointAndDistanceToSegmentMeters(
        point: LngLat,
        a: (Double, Double),
        b: (Double, Double)
    ) -> (point: LngLat, distanceMeters: Double) {
        let originLat = point.lat
        let p = project(lng: point.lng, lat: point.lat, originLat: originLat)
        let pa = project(lng: a.0, lat: a.1, originLat: originLat)
        let pb = project(lng: b.0, lat: b.1, originLat: originLat)
        let dx = pb.x - pa.x
        let dy = pb.y - pa.y
        let lenSq = dx * dx + dy * dy
        if lenSq == 0 {
            let dist = hypot(p.x - pa.x, p.y - pa.y)
            return (LngLat(lng: a.0, lat: a.1), dist)
        }
        var t = ((p.x - pa.x) * dx + (p.y - pa.y) * dy) / lenSq
        t = max(0, min(1, t))
        let cx = pa.x + t * dx
        let cy = pa.y + t * dy
        let dist = hypot(p.x - cx, p.y - cy)
        let m = metersPerDegree(lat: originLat)
        let unprojected = LngLat(lng: cx / m.mx, lat: cy / m.my)
        return (unprojected, dist)
    }

    nonisolated static func nearestPointOnLineStringMeters(
        point: LngLat,
        coordinates: [[Double]]
    ) -> (point: LngLat, distanceMeters: Double)? {
        if coordinates.isEmpty { return nil }
        if coordinates.count == 1 {
            guard coordinates[0].count >= 2 else { return nil }
            let pt = LngLat(lng: coordinates[0][0], lat: coordinates[0][1])
            return (pt, haversineMeters(point, pt))
        }
        var minDist = Double.infinity
        var bestPoint: LngLat?
        for i in 0..<(coordinates.count - 1) {
            guard coordinates[i].count >= 2, coordinates[i + 1].count >= 2 else { continue }
            let res = nearestPointAndDistanceToSegmentMeters(
                point: point,
                a: (coordinates[i][0], coordinates[i][1]),
                b: (coordinates[i + 1][0], coordinates[i + 1][1])
            )
            if res.distanceMeters < minDist {
                minDist = res.distanceMeters
                bestPoint = res.point
            }
        }
        guard let bestPoint else { return nil }
        return (bestPoint, minDist)
    }

    nonisolated static func nearestPointOnFeatureMeters(
        point: LngLat,
        feature: ParkingFeature
    ) -> (point: LngLat, distanceMeters: Double)? {
        var minDist = Double.infinity
        var bestPoint: LngLat?
        for part in lineParts(feature.geometry) {
            guard let res = nearestPointOnLineStringMeters(point: point, coordinates: part) else { continue }
            if res.distanceMeters < minDist {
                minDist = res.distanceMeters
                bestPoint = res.point
            }
        }
        guard let bestPoint else { return nil }
        return (bestPoint, minDist)
    }

    nonisolated static func distancePointToLineStringMeters(
        point: LngLat,
        coordinates: [[Double]]
    ) -> Double {
        nearestPointOnLineStringMeters(point: point, coordinates: coordinates)?.distanceMeters ?? .infinity
    }

    nonisolated static func distancePointToFeatureMeters(
        point: LngLat,
        feature: ParkingFeature
    ) -> Double {
        nearestPointOnFeatureMeters(point: point, feature: feature)?.distanceMeters ?? .infinity
    }

    nonisolated static func polylineLengthMeters(_ coordinates: [[Double]]) -> Double {
        guard coordinates.count >= 2 else { return 0 }
        var total = 0.0
        for i in 0..<(coordinates.count - 1) {
            guard coordinates[i].count >= 2, coordinates[i + 1].count >= 2 else { continue }
            let p1 = LngLat(lng: coordinates[i][0], lat: coordinates[i][1])
            let p2 = LngLat(lng: coordinates[i + 1][0], lat: coordinates[i + 1][1])
            total += haversineMeters(p1, p2)
        }
        return total
    }

    nonisolated static func cumulativeLengthsMeters(_ coordinates: [[Double]]) -> [Double] {
        guard !coordinates.isEmpty else { return [] }
        var lengths = [0.0]
        lengths.reserveCapacity(coordinates.count)
        var total = 0.0
        for i in 0..<(coordinates.count - 1) {
            guard coordinates[i].count >= 2, coordinates[i + 1].count >= 2 else {
                lengths.append(total)
                continue
            }
            let p1 = LngLat(lng: coordinates[i][0], lat: coordinates[i][1])
            let p2 = LngLat(lng: coordinates[i + 1][0], lat: coordinates[i + 1][1])
            total += haversineMeters(p1, p2)
            lengths.append(total)
        }
        return lengths
    }

    nonisolated static func projectPointToSegmentMeters(
        point: LngLat,
        a: (Double, Double),
        b: (Double, Double)
    ) -> (point: LngLat, lateralDistanceMeters: Double, t: Double, segmentLengthMeters: Double) {
        let originLat = point.lat
        let p = project(lng: point.lng, lat: point.lat, originLat: originLat)
        let pa = project(lng: a.0, lat: a.1, originLat: originLat)
        let pb = project(lng: b.0, lat: b.1, originLat: originLat)
        let dx = pb.x - pa.x
        let dy = pb.y - pa.y
        let lenSq = dx * dx + dy * dy
        let segLen = sqrt(lenSq)
        if lenSq == 0 {
            let dist = hypot(p.x - pa.x, p.y - pa.y)
            return (LngLat(lng: a.0, lat: a.1), dist, 0.0, 0.0)
        }
        var t = ((p.x - pa.x) * dx + (p.y - pa.y) * dy) / lenSq
        t = max(0, min(1, t))
        let cx = pa.x + t * dx
        let cy = pa.y + t * dy
        let dist = hypot(p.x - cx, p.y - cy)
        let m = metersPerDegree(lat: originLat)
        let unprojected = LngLat(lng: cx / m.mx, lat: cy / m.my)
        return (unprojected, dist, t, segLen)
    }

    nonisolated static func distancePointToLineStringDetailed(
        point: LngLat,
        coordinates: [[Double]]
    ) -> (distanceMeters: Double, projectionPoint: LngLat, distanceAlongMeters: Double, fraction: Double)? {
        guard coordinates.count >= 2 else { return nil }
        let cumulative = cumulativeLengthsMeters(coordinates)
        let totalLength = cumulative.last ?? 0
        guard totalLength > 0 else { return nil }

        var minDist = Double.infinity
        var bestProj: LngLat?
        var bestDistAlong: Double = 0

        for i in 0..<(coordinates.count - 1) {
            guard coordinates[i].count >= 2, coordinates[i + 1].count >= 2 else { continue }
            let res = projectPointToSegmentMeters(
                point: point,
                a: (coordinates[i][0], coordinates[i][1]),
                b: (coordinates[i + 1][0], coordinates[i + 1][1])
            )
            if res.lateralDistanceMeters < minDist {
                minDist = res.lateralDistanceMeters
                bestProj = res.point
                let startSeg = cumulative[i]
                let segLen = cumulative[i + 1] - startSeg
                bestDistAlong = startSeg + res.t * segLen
            }
        }

        guard let bestProj else { return nil }
        let fraction = max(0.0, min(1.0, bestDistAlong / totalLength))
        return (minDist, bestProj, bestDistAlong, fraction)
    }

    nonisolated static func pointAtDistanceMeters(
        coordinates: [[Double]],
        distanceMeters: Double,
        cumulative: [Double]? = nil
    ) -> LngLat? {
        guard coordinates.count >= 2 else { return nil }
        let cum = cumulative ?? cumulativeLengthsMeters(coordinates)
        let totalLen = cum.last ?? 0
        if distanceMeters <= 0 {
            return LngLat(lng: coordinates[0][0], lat: coordinates[0][1])
        }
        if distanceMeters >= totalLen {
            let last = coordinates[coordinates.count - 1]
            return LngLat(lng: last[0], lat: last[1])
        }

        for i in 0..<(coordinates.count - 1) {
            let s0 = cum[i]
            let s1 = cum[i + 1]
            if distanceMeters >= s0 && distanceMeters <= s1 {
                let segLen = s1 - s0
                let t = segLen > 0 ? (distanceMeters - s0) / segLen : 0
                let c0 = coordinates[i]
                let c1 = coordinates[i + 1]
                let lng = c0[0] + t * (c1[0] - c0[0])
                let lat = c0[1] + t * (c1[1] - c0[1])
                return LngLat(lng: lng, lat: lat)
            }
        }
        let last = coordinates[coordinates.count - 1]
        return LngLat(lng: last[0], lat: last[1])
    }

    nonisolated static func extractSubPolyline(
        coordinates: [[Double]],
        startMeters: Double,
        endMeters: Double,
        cumulative: [Double]? = nil
    ) -> [[Double]] {
        guard coordinates.count >= 2 else { return [] }
        let cum = cumulative ?? cumulativeLengthsMeters(coordinates)
        let totalLength = cum.last ?? 0
        let s = max(0.0, min(totalLength, startMeters))
        let e = max(0.0, min(totalLength, endMeters))
        guard e > s else { return [] }

        guard let startPt = pointAtDistanceMeters(coordinates: coordinates, distanceMeters: s, cumulative: cum),
              let endPt = pointAtDistanceMeters(coordinates: coordinates, distanceMeters: e, cumulative: cum) else {
            return []
        }

        var result: [[Double]] = [[startPt.lng, startPt.lat]]
        for i in 1..<(coordinates.count - 1) {
            let d = cum[i]
            if d > (s + 0.05) && d < (e - 0.05) {
                result.append([coordinates[i][0], coordinates[i][1]])
            }
        }
        result.append([endPt.lng, endPt.lat])
        return result
    }

    nonisolated static func subtractIntervals(
        coordinates: [[Double]],
        blockedRanges: [(start: Double, end: Double)],
        minLengthMeters: Double = 1.5
    ) -> [[[Double]]] {
        guard coordinates.count >= 2 else { return [] }
        let cum = cumulativeLengthsMeters(coordinates)
        let totalLength = cum.last ?? 0
        guard totalLength >= minLengthMeters else { return [] }

        if blockedRanges.isEmpty {
            return [coordinates]
        }

        // 1. Normalize & clamp blocked ranges
        var clamped: [(start: Double, end: Double)] = []
        for range in blockedRanges {
            let s = max(0.0, min(totalLength, min(range.start, range.end)))
            let e = max(0.0, min(totalLength, max(range.start, range.end)))
            if e > s {
                clamped.append((s, e))
            }
        }

        guard !clamped.isEmpty else { return [coordinates] }

        // 2. Merge overlapping blocked ranges
        clamped.sort { $0.start < $1.start }
        var merged: [(start: Double, end: Double)] = [clamped[0]]
        for i in 1..<clamped.count {
            let cur = clamped[i]
            let lastIdx = merged.count - 1
            if cur.start <= (merged[lastIdx].end + 0.1) {
                merged[lastIdx].end = max(merged[lastIdx].end, cur.end)
            } else {
                merged.append(cur)
            }
        }

        // 3. Invert to get free intervals
        var freeIntervals: [(start: Double, end: Double)] = []
        var curPos = 0.0
        for block in merged {
            if block.start > (curPos + minLengthMeters) {
                freeIntervals.append((curPos, block.start))
            }
            curPos = max(curPos, block.end)
        }
        if totalLength > (curPos + minLengthMeters) {
            freeIntervals.append((curPos, totalLength))
        }

        // 4. Extract sub-polylines for free intervals
        var subPolylines: [[[Double]]] = []
        for interval in freeIntervals {
            let sub = extractSubPolyline(
                coordinates: coordinates,
                startMeters: interval.start,
                endMeters: interval.end,
                cumulative: cum
            )
            if sub.count >= 2 && polylineLengthMeters(sub) >= minLengthMeters {
                subPolylines.append(sub)
            }
        }

        return subPolylines
    }

    nonisolated static func geometriesOverlapMeters(
        _ a: ParkingGeometry,
        _ b: ParkingGeometry,
        toleranceMeters: Double = 4.0,
        minOverlapLengthMeters: Double = 2.0
    ) -> Bool {
        let partsA = lineParts(a)
        let partsB = lineParts(b)
        for partA in partsA {
            guard partA.count >= 2 else { continue }
            let lenA = polylineLengthMeters(partA)
            guard lenA >= minOverlapLengthMeters else { continue }
            for partB in partsB {
                guard partB.count >= 2 else { continue }
                if let range = CurbOverlapResolver.findOverlapRange(
                    targetCoords: partA,
                    targetLength: lenA,
                    otherCoords: partB,
                    toleranceMeters: toleranceMeters
                ) {
                    if (range.end - range.start) >= minOverlapLengthMeters {
                        return true
                    }
                }
            }
        }
        return false
    }
}
