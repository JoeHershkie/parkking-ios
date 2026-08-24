import Foundation

enum ParkingGeoJSONDecoder {
    struct DecodeResult: Sendable {
        var features: [ParkingFeature]
        var skippedPoints: Int
    }

    nonisolated static func decode(_ data: Data) throws -> DecodeResult {
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        guard let root = json as? [String: Any],
              let rawFeatures = root["features"] as? [[String: Any]]
        else {
            throw ParkingDataError.decodeFailed("Missing FeatureCollection features array")
        }

        var features: [ParkingFeature] = []
        features.reserveCapacity(rawFeatures.count)
        var skippedPoints = 0

        for (index, raw) in rawFeatures.enumerated() {
            guard let geometryObj = raw["geometry"] as? [String: Any],
                  let type = geometryObj["type"] as? String
            else { continue }

            if type == "Point" {
                skippedPoints += 1
                continue
            }

            guard let geometry = decodeGeometry(type: type, object: geometryObj) else {
                continue
            }

            let propsObj = raw["properties"] as? [String: Any] ?? [:]
            let props = decodeProperties(propsObj)
            let feature = ParkingFeature(
                id: FeatureID.fromSourceID(props.sourceID, index: index),
                geometry: geometry,
                properties: props
            )
            features.append(feature)
        }

        return DecodeResult(features: features, skippedPoints: skippedPoints)
    }

    nonisolated private static func decodeGeometry(
        type: String,
        object: [String: Any]
    ) -> ParkingGeometry? {
        switch type {
        case "LineString":
            guard let coords = numberPairs(object["coordinates"]) else { return nil }
            let mapped = coords.compactMap(validPair)
            guard mapped.count >= 2 else { return nil }
            return .lineString(coordinates: mapped)

        case "MultiLineString":
            guard let parts = numberPairLists(object["coordinates"]) else { return nil }
            let mapped = parts.map { $0.compactMap(validPair) }.filter { $0.count >= 2 }
            guard !mapped.isEmpty else { return nil }
            return .multiLineString(coordinates: mapped)

        case "Polygon", "GeometryCollection":
            return nil

        default:
            return nil
        }
    }

    nonisolated private static func decodeProperties(_ obj: [String: Any]) -> ParkingProperties {
        let highway = stringValue(obj["Highway"]) ?? ""
        let rule = stringValue(obj["Rule"]) ?? ""
        let category = stringValue(obj["schedule_category"]) ?? "unknown"
        let side = stringValue(obj["Side"]) ?? ""
        let max = stringValue(obj["max"])
        let maxMinutes = intValue(obj["maxMinutes"])
        let disjoint = boolValue(obj["disjoint_block"])
        let sourceID = stringValue(obj["_id"])
        let sideMode = stringValue(obj["side_mode"])
        let curbGeometryMethod = stringValue(obj["curb_geometry_method"])
        let curbConfidence = doubleValue(obj["curb_confidence"])
        let curbCoverage = doubleValue(obj["curb_coverage"])
        let medianOffsetM = doubleValue(obj["median_offset_m"])
        let curbOverride = boolValue(obj["curb_override"])
        let curbWarnings = stringList(obj["curb_warnings"])
        let centrelineIDs = intList(obj["centreline_ids"])
        let roadEdgeObjectIDs = intList(obj["road_edge_object_ids"])
        let centrelineConstruction = stringValue(obj["centreline_construction"])
        let mergeDroppedComponent = boolValue(obj["merge_dropped_component"])

        var schedule: Schedule?
        if let scheduleObj = obj["schedule"] as? [String: Any] {
            schedule = Schedule(dictionary: scheduleObj)
        }

        return ParkingProperties(
            highway: highway,
            rule: rule,
            scheduleCategory: category,
            side: side,
            max: max,
            schedule: schedule,
            maxMinutes: maxMinutes,
            disjointBlock: disjoint,
            sourceID: sourceID,
            sideMode: sideMode,
            curbGeometryMethod: curbGeometryMethod,
            curbConfidence: curbConfidence,
            curbCoverage: curbCoverage,
            medianOffsetM: medianOffsetM,
            curbOverride: curbOverride,
            curbWarnings: curbWarnings,
            centrelineIDs: centrelineIDs,
            roadEdgeObjectIDs: roadEdgeObjectIDs,
            centrelineConstruction: centrelineConstruction,
            mergeDroppedComponent: mergeDroppedComponent
        )
    }

    nonisolated private static func stringValue(_ any: Any?) -> String? {
        if let s = any as? String { return s }
        if any is NSNull { return nil }
        if let n = any as? NSNumber { return n.stringValue }
        return nil
    }

    nonisolated private static func intValue(_ any: Any?) -> Int? {
        if let i = any as? Int { return i }
        if let d = any as? Double { return Int(d.rounded()) }
        if let n = any as? NSNumber { return n.intValue }
        if let s = any as? String, let d = Double(s) { return Int(d.rounded()) }
        return nil
    }

    nonisolated private static func doubleValue(_ any: Any?) -> Double? {
        if let d = any as? Double { return d }
        if let i = any as? Int { return Double(i) }
        if let n = any as? NSNumber { return n.doubleValue }
        if let s = any as? String, let d = Double(s) { return d }
        return nil
    }

    nonisolated private static func boolValue(_ any: Any?) -> Bool? {
        if any is NSNull || any == nil { return nil }
        if let b = any as? Bool { return b }
        if let s = any as? String {
            let lower = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if lower.isEmpty || lower == "null" { return nil }
            if ["true", "1", "yes", "y"].contains(lower) { return true }
            if ["false", "0", "no", "n"].contains(lower) { return false }
            // Opaque non-empty string (e.g. block id) → present/true.
            return true
        }
        if let n = any as? NSNumber { return n.boolValue }
        return nil
    }

    nonisolated private static func stringList(_ any: Any?) -> [String]? {
        if any is NSNull || any == nil { return nil }
        if let arr = any as? [Any] {
            return arr.compactMap { stringValue($0) }
        }
        if let s = any as? String {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed == "null" { return nil }
            if let data = trimmed.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data)
            {
                return stringList(json)
            }
            let parts = trimmed
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return parts
        }
        return nil
    }

    nonisolated private static func intList(_ any: Any?) -> [Int]? {
        if any is NSNull || any == nil { return nil }
        if let arr = any as? [Any] {
            return arr.compactMap { intValue($0) }
        }
        if let s = any as? String {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed == "null" { return nil }
            if let data = trimmed.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data)
            {
                return intList(json)
            }
            let parts = trimmed
                .split(separator: ",")
                .compactMap { intValue($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            return parts
        }
        return nil
    }

    nonisolated private static func validPair(_ pair: [NSNumber]) -> [Double]? {
        guard pair.count >= 2 else { return nil }
        let lng = pair[0].doubleValue
        let lat = pair[1].doubleValue
        guard lng.isFinite, lat.isFinite else { return nil }
        return [lng, lat]
    }

    nonisolated private static func validPair(_ pair: [Double]) -> [Double]? {
        guard pair.count >= 2 else { return nil }
        let lng = pair[0]
        let lat = pair[1]
        guard lng.isFinite, lat.isFinite else { return nil }
        return [lng, lat]
    }

    nonisolated private static func numberPairs(_ any: Any?) -> [[NSNumber]]? {
        guard let arr = any as? [Any] else { return nil }
        var out: [[NSNumber]] = []
        for item in arr {
            guard let pair = item as? [Any], pair.count >= 2,
                  let lng = pair[0] as? NSNumber,
                  let lat = pair[1] as? NSNumber
            else { continue }
            out.append([lng, lat])
        }
        return out
    }

    nonisolated private static func numberPairLists(_ any: Any?) -> [[[NSNumber]]]? {
        guard let arr = any as? [Any] else { return nil }
        var out: [[[NSNumber]]] = []
        for part in arr {
            if let pairs = numberPairs(part) {
                out.append(pairs)
            }
        }
        return out
    }
}
