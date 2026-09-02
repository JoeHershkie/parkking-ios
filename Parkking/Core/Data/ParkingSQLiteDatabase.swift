import CoreLocation
import Foundation
import SQLite3

/// High-performance read-only SQLite database reader for pre-indexed curb features.
///
/// Executes hardware-accelerated bounding box spatial queries using the SQLite R-Tree index
/// (`rtree_features_idx`) and decodes WKB geometries with zero intermediate overhead.
nonisolated final class ParkingSQLiteDatabase: @unchecked Sendable {
    enum SQLiteError: LocalizedError, Sendable, Equatable {
        case openFailed(String)
        case prepareFailed(String)
        case executionFailed(String)
        case missingColumn(String)

        var errorDescription: String? {
            switch self {
            case .openFailed(let msg): return "Failed to open SQLite database: \(msg)"
            case .prepareFailed(let msg): return "Failed to prepare SQLite statement: \(msg)"
            case .executionFailed(let msg): return "SQLite query error: \(msg)"
            case .missingColumn(let msg): return "SQLite schema missing column: \(msg)"
            }
        }
    }

    private let db: OpaquePointer

    init(url: URL) throws {
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX
        let status = sqlite3_open_v2(url.path, &handle, flags, nil)
        guard status == SQLITE_OK, let validHandle = handle else {
            let errMsg = handle != nil ? String(cString: sqlite3_errmsg(handle)) : "Unknown error"
            if let handle { sqlite3_close_v2(handle) }
            throw SQLiteError.openFailed(errMsg)
        }
        self.db = validHandle
    }

    convenience init(path: String) throws {
        try self.init(url: URL(fileURLWithPath: path))
    }

    deinit {
        sqlite3_close_v2(db)
    }

    /// Total number of features stored in the database.
    func featureCount() -> Int {
        var stmt: OpaquePointer?
        let sql = "SELECT COUNT(*) FROM features;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return 0
        }
        defer { sqlite3_finalize(stmt) }
        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int64(stmt, 0))
        }
        return 0
    }

    /// Queries features intersecting a geographic bounding box using the SQLite R-Tree index.
    func queryBBox(
        minLng: Double,
        minLat: Double,
        maxLng: Double,
        maxLat: Double
    ) throws -> [ParkingFeature] {
        let sql = """
            SELECT
                f.id, f.highway, f.rule, f.schedule_category, f.side, f.side_mode,
                f.max, f.max_minutes, f.schedule_json, f.is_snow_route, f.streetcar_corridor,
                f.former_municipality, f.regional_winter_rule, f.permit_area_id, f.permit_parking_active,
                f.has_hydrant, f.hydrant_count, f.hydrant_setback_m, f.curb_geometry_method,
                f.curb_confidence, f.curb_coverage, f.median_offset_m, f.centreline_ids_json, f.geometry_wkb
            FROM features f
            JOIN rtree_features_idx r ON f.rowid = r.id
            WHERE r.min_lng <= ? AND r.max_lng >= ?
              AND r.min_lat <= ? AND r.max_lat >= ?;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        // Bind R-Tree query bounds:
        // r.min_lng <= maxLng AND r.max_lng >= minLng AND r.min_lat <= maxLat AND r.max_lat >= minLat
        sqlite3_bind_double(stmt, 1, maxLng)
        sqlite3_bind_double(stmt, 2, minLng)
        sqlite3_bind_double(stmt, 3, maxLat)
        sqlite3_bind_double(stmt, 4, minLat)

        return try readFeaturesFromStatement(stmt)
    }

    /// Loads all features in the database.
    func loadAllFeatures() throws -> [ParkingFeature] {
        let sql = """
            SELECT
                id, highway, rule, schedule_category, side, side_mode,
                max, max_minutes, schedule_json, is_snow_route, streetcar_corridor,
                former_municipality, regional_winter_rule, permit_area_id, permit_parking_active,
                has_hydrant, hydrant_count, hydrant_setback_m, curb_geometry_method,
                curb_confidence, curb_coverage, median_offset_m, centreline_ids_json, geometry_wkb
            FROM features ORDER BY rowid;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        return try readFeaturesFromStatement(stmt)
    }

    private func readFeaturesFromStatement(_ stmt: OpaquePointer?) throws -> [ParkingFeature] {
        var results: [ParkingFeature] = []

        while sqlite3_step(stmt) == SQLITE_ROW {
            let fid = stringColumn(stmt, 0) ?? ""
            let highway = stringColumn(stmt, 1) ?? ""
            let rule = stringColumn(stmt, 2) ?? ""
            let scheduleCategory = stringColumn(stmt, 3) ?? "no_parking"
            let side = stringColumn(stmt, 4) ?? "Both"
            let sideMode = stringColumn(stmt, 5)
            let maxStr = stringColumn(stmt, 6)
            let maxMinutes = intOptionalColumn(stmt, 7)
            let scheduleJSON = stringColumn(stmt, 8)
            let isSnowRoute = boolColumn(stmt, 9)
            let streetcarCorridor = boolColumn(stmt, 10)
            let formerMunicipality = stringColumn(stmt, 11)
            let regionalWinterRule = stringColumn(stmt, 12)
            let permitAreaID = stringColumn(stmt, 13)
            let permitParkingActive = boolColumn(stmt, 14)
            let hasHydrant = boolColumn(stmt, 15)
            let hydrantCount = intColumn(stmt, 16)
            let hydrantSetbackM = doubleOptionalColumn(stmt, 17)
            let curbGeometryMethod = stringColumn(stmt, 18)
            let curbConfidence = doubleOptionalColumn(stmt, 19)
            let curbCoverage = doubleOptionalColumn(stmt, 20)
            let medianOffsetM = doubleOptionalColumn(stmt, 21)
            let centrelineIdsJSON = stringColumn(stmt, 22)

            guard let blobPtr = sqlite3_column_blob(stmt, 23) else {
                continue
            }
            let blobBytes = Int(sqlite3_column_bytes(stmt, 23))
            guard blobBytes > 0 else { continue }
            let wkbData = Data(bytes: blobPtr, count: blobBytes)

            guard let decodedGeom = try? WKBDecoder.decode(wkbData) else {
                continue
            }

            var schedule: Schedule? = nil
            if let scheduleJSON, let data = scheduleJSON.data(using: .utf8) {
                schedule = try? JSONDecoder().decode(Schedule.self, from: data)
            }

            var centrelineIDs: [Int]? = nil
            if let centrelineIdsJSON, let data = centrelineIdsJSON.data(using: .utf8) {
                centrelineIDs = try? JSONDecoder().decode([Int].self, from: data)
            }

            let props = ParkingProperties(
                highway: highway,
                rule: rule,
                scheduleCategory: scheduleCategory,
                side: side,
                max: maxStr,
                schedule: schedule,
                maxMinutes: maxMinutes,
                sourceID: fid,
                sideMode: sideMode,
                curbGeometryMethod: curbGeometryMethod,
                curbConfidence: curbConfidence,
                curbCoverage: curbCoverage,
                medianOffsetM: medianOffsetM,
                centrelineIDs: centrelineIDs,
                isSnowRoute: isSnowRoute ? true : nil,
                streetcarCorridor: streetcarCorridor ? true : nil,
                formerMunicipality: formerMunicipality,
                regionalWinterRule: regionalWinterRule,
                permitAreaID: permitAreaID,
                permitParkingActive: permitParkingActive ? true : nil,
                hasHydrant: hasHydrant ? true : nil,
                hydrantCount: hydrantCount > 0 ? hydrantCount : nil,
                hydrantSetbackM: hydrantSetbackM
            )

            let feature = ParkingFeature(
                id: FeatureID(fid),
                geometry: decodedGeom.geometry,
                properties: props,
                coordinateParts: decodedGeom.coordinateParts
            )
            results.append(feature)
        }

        return results
    }

    private func stringColumn(_ stmt: OpaquePointer?, _ col: Int32) -> String? {
        guard let cStr = sqlite3_column_text(stmt, col) else { return nil }
        return String(cString: cStr)
    }

    private func intColumn(_ stmt: OpaquePointer?, _ col: Int32) -> Int {
        Int(sqlite3_column_int64(stmt, col))
    }

    private func intOptionalColumn(_ stmt: OpaquePointer?, _ col: Int32) -> Int? {
        if sqlite3_column_type(stmt, col) == SQLITE_NULL { return nil }
        return Int(sqlite3_column_int64(stmt, col))
    }

    private func doubleOptionalColumn(_ stmt: OpaquePointer?, _ col: Int32) -> Double? {
        if sqlite3_column_type(stmt, col) == SQLITE_NULL { return nil }
        return sqlite3_column_double(stmt, col)
    }

    private func boolColumn(_ stmt: OpaquePointer?, _ col: Int32) -> Bool {
        sqlite3_column_int(stmt, col) != 0
    }
}
