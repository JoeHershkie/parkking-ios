import CoreLocation
import Foundation
import SQLite3
import Testing
@testable import Parkking

@Suite("ParkingSQLiteDatabase Tests")
struct ParkingSQLiteDatabaseTests {
    private func createTestDatabaseURL() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let dbURL = tempDir.appendingPathComponent("test_parking_\(UUID().uuidString).sqlite")

        var db: OpaquePointer?
        let openStatus = sqlite3_open_v2(
            dbURL.path,
            &db,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE,
            nil
        )
        guard openStatus == SQLITE_OK, let db else {
            Issue.record("Failed to create test SQLite database")
            return dbURL
        }
        defer { sqlite3_close_v2(db) }

        // Create schema matching export_sqlite.py
        let createFeaturesSQL = """
        CREATE TABLE features (
            rowid INTEGER PRIMARY KEY,
            id TEXT NOT NULL UNIQUE,
            highway TEXT,
            rule TEXT,
            schedule_category TEXT,
            side TEXT,
            side_mode TEXT,
            max TEXT,
            max_minutes INTEGER,
            schedule_json TEXT,
            is_snow_route INTEGER DEFAULT 0,
            streetcar_corridor INTEGER DEFAULT 0,
            former_municipality TEXT,
            regional_winter_rule TEXT,
            permit_area_id TEXT,
            permit_parking_active INTEGER DEFAULT 0,
            has_hydrant INTEGER DEFAULT 0,
            hydrant_count INTEGER DEFAULT 0,
            hydrant_setback_m REAL,
            curb_geometry_method TEXT,
            curb_confidence REAL,
            curb_coverage REAL,
            median_offset_m REAL,
            centreline_ids_json TEXT,
            geometry_wkb BLOB NOT NULL
        );
        """
        sqlite3_exec(db, createFeaturesSQL, nil, nil, nil)

        let createRtreeSQL = """
        CREATE VIRTUAL TABLE rtree_features_idx USING rtree(
            id,
            min_lng,
            max_lng,
            min_lat,
            max_lat
        );
        """
        sqlite3_exec(db, createRtreeSQL, nil, nil, nil)

        func makeWKB(x1: Double, y1: Double, x2: Double, y2: Double) -> Data {
            var data = Data()
            data.append(contentsOf: [UInt8(1)]) // Little Endian
            var typeLE: UInt32 = 2
            data.append(Data(bytes: &typeLE, count: 4))
            var countLE: UInt32 = 2
            data.append(Data(bytes: &countLE, count: 4))
            var p1x = x1; var p1y = y1
            data.append(Data(bytes: &p1x, count: 8))
            data.append(Data(bytes: &p1y, count: 8))
            var p2x = x2; var p2y = y2
            data.append(Data(bytes: &p2x, count: 8))
            data.append(Data(bytes: &p2y, count: 8))
            return data
        }

        let wkb1 = makeWKB(x1: -79.400, y1: 43.650, x2: -79.390, y2: 43.651)
        let wkb2 = makeWKB(x1: -79.380, y1: 43.660, x2: -79.370, y2: 43.661)

        let insertFeatureSQL = """
        INSERT INTO features (
            rowid, id, highway, rule, schedule_category, side, side_mode,
            max, max_minutes, schedule_json, is_snow_route, streetcar_corridor,
            former_municipality, regional_winter_rule, permit_area_id, permit_parking_active,
            has_hydrant, hydrant_count, hydrant_setback_m, curb_geometry_method,
            curb_confidence, curb_coverage, median_offset_m, centreline_ids_json, geometry_wkb
        ) VALUES (
            ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
        );
        """

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, insertFeatureSQL, -1, &stmt, nil)

        // Row 1
        sqlite3_bind_int64(stmt, 1, 1)
        sqlite3_bind_text(stmt, 2, "feat_queen", -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, "QUEEN ST W", -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 4, "No Parking Anytime", -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 5, "no_parking", -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 6, "North", -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 7, "single", -1, SQLITE_TRANSIENT)
        sqlite3_bind_null(stmt, 8)
        sqlite3_bind_null(stmt, 9)
        sqlite3_bind_text(stmt, 10, "{\"v\":1,\"status\":\"anytime\",\"source\":\"Anytime\",\"windows\":[]}", -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 11, 0)
        sqlite3_bind_int(stmt, 12, 1)
        sqlite3_bind_text(stmt, 13, "TORONTO", -1, SQLITE_TRANSIENT)
        sqlite3_bind_null(stmt, 14)
        sqlite3_bind_text(stmt, 15, "8A", -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 16, 1)
        sqlite3_bind_int(stmt, 17, 1)
        sqlite3_bind_int(stmt, 18, 2)
        sqlite3_bind_double(stmt, 19, 3.0)
        sqlite3_bind_text(stmt, 20, "road_edge_matched", -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 21, 0.95)
        sqlite3_bind_double(stmt, 22, 1.0)
        sqlite3_bind_double(stmt, 23, 4.2)
        sqlite3_bind_text(stmt, 24, "[1001, 1002]", -1, SQLITE_TRANSIENT)
        wkb1.withUnsafeBytes { raw in
            sqlite3_bind_blob(stmt, 25, raw.baseAddress, Int32(raw.count), SQLITE_TRANSIENT)
        }
        let step1 = sqlite3_step(stmt)
        #expect(step1 == SQLITE_DONE)
        sqlite3_reset(stmt)
        sqlite3_clear_bindings(stmt)

        // Row 2
        sqlite3_bind_int64(stmt, 1, 2)
        sqlite3_bind_text(stmt, 2, "feat_bloor", -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, "BLOOR ST W", -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 4, "2 Hour Parking", -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 5, "restricted_periods", -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 6, "South", -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 7, "single", -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 8, "2 hours", -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(stmt, 9, 120)
        sqlite3_bind_null(stmt, 10)
        sqlite3_bind_int(stmt, 11, 1)
        sqlite3_bind_int(stmt, 12, 0)
        sqlite3_bind_text(stmt, 13, "TORONTO", -1, SQLITE_TRANSIENT)
        sqlite3_bind_null(stmt, 14)
        sqlite3_bind_null(stmt, 15)
        sqlite3_bind_int(stmt, 16, 0)
        sqlite3_bind_int(stmt, 17, 0)
        sqlite3_bind_int(stmt, 18, 0)
        sqlite3_bind_null(stmt, 19)
        sqlite3_bind_text(stmt, 20, "centreline_fallback", -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 21, 0.5)
        sqlite3_bind_double(stmt, 22, 0.8)
        sqlite3_bind_null(stmt, 23)
        sqlite3_bind_null(stmt, 24)
        wkb2.withUnsafeBytes { raw in
            sqlite3_bind_blob(stmt, 25, raw.baseAddress, Int32(raw.count), SQLITE_TRANSIENT)
        }
        let step2 = sqlite3_step(stmt)
        #expect(step2 == SQLITE_DONE)
        sqlite3_finalize(stmt)

        // Insert into R-Tree
        let insertRtreeSQL = "INSERT INTO rtree_features_idx (id, min_lng, max_lng, min_lat, max_lat) VALUES (?, ?, ?, ?, ?);"
        sqlite3_prepare_v2(db, insertRtreeSQL, -1, &stmt, nil)

        // Rtree row 1
        sqlite3_bind_int64(stmt, 1, 1)
        sqlite3_bind_double(stmt, 2, -79.400)
        sqlite3_bind_double(stmt, 3, -79.390)
        sqlite3_bind_double(stmt, 4, 43.650)
        sqlite3_bind_double(stmt, 5, 43.651)
        sqlite3_step(stmt)
        sqlite3_reset(stmt)
        sqlite3_clear_bindings(stmt)

        // Rtree row 2
        sqlite3_bind_int64(stmt, 1, 2)
        sqlite3_bind_double(stmt, 2, -79.380)
        sqlite3_bind_double(stmt, 3, -79.370)
        sqlite3_bind_double(stmt, 4, 43.660)
        sqlite3_bind_double(stmt, 5, 43.661)
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)

        return dbURL
    }

    @Test("Opens SQLite database and reads total feature count")
    func testFeatureCount() throws {
        let dbURL = try createTestDatabaseURL()
        defer { try? FileManager.default.removeItem(at: dbURL) }

        let sqliteDb = try ParkingSQLiteDatabase(url: dbURL)
        #expect(sqliteDb.featureCount() == 2)
    }

    @Test("Executes R-Tree spatial query filtering features")
    func testSpatialRTreeQuery() throws {
        let dbURL = try createTestDatabaseURL()
        defer { try? FileManager.default.removeItem(at: dbURL) }

        let sqliteDb = try ParkingSQLiteDatabase(url: dbURL)

        // Spatial query around Queen St only
        let queenResults = try sqliteDb.queryBBox(
            minLng: -79.410,
            minLat: 43.649,
            maxLng: -79.385,
            maxLat: 43.655
        )
        #expect(queenResults.count == 1)
        let queen = try #require(queenResults.first)
        #expect(queen.id.rawValue == "feat_queen")
        #expect(queen.properties.highway == "QUEEN ST W")
        #expect(queen.properties.permitAreaID == "8A")
        #expect(queen.properties.permitParkingActive == true)
        #expect(queen.properties.hasHydrant == true)
        #expect(queen.properties.hydrantCount == 2)
        #expect(queen.properties.hydrantSetbackM == 3.0)
        #expect(queen.properties.streetcarCorridor == true)
        #expect(queen.properties.centrelineIDs == [1001, 1002])

        // Spatial query across both features
        let allResults = try sqliteDb.queryBBox(
            minLng: -79.410,
            minLat: 43.640,
            maxLng: -79.360,
            maxLat: 43.670
        )
        #expect(allResults.count == 2)

        // Disjoint spatial query (Scarborough coordinates)
        let disjointResults = try sqliteDb.queryBBox(
            minLng: -79.200,
            minLat: 43.700,
            maxLng: -79.150,
            maxLat: 43.750
        )
        #expect(disjointResults.isEmpty)
    }

    @Test("Loads all features and maps pipeline fields accurately")
    func testLoadAllFeatures() throws {
        let dbURL = try createTestDatabaseURL()
        defer { try? FileManager.default.removeItem(at: dbURL) }

        let sqliteDb = try ParkingSQLiteDatabase(url: dbURL)
        let features = try sqliteDb.loadAllFeatures()
        #expect(features.count == 2)

        let bloor = try #require(features.first { $0.id.rawValue == "feat_bloor" })
        #expect(bloor.properties.highway == "BLOOR ST W")
        #expect(bloor.properties.isSnowRoute == true)
        #expect(bloor.properties.maxMinutes == 120)
        #expect(bloor.properties.max == "2 hours")
        #expect(bloor.properties.curbGeometryMethod == "centreline_fallback")
        #expect(bloor.properties.curbConfidence == 0.5)
    }
}
