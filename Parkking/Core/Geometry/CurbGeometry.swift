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
        guard !coordinates.isEmpty else { return nil }
        let mid = coordinates[coordinates.count / 2]
        guard mid.count >= 2 else { return nil }
        return LngLat(lng: mid[0], lat: mid[1])
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
}
