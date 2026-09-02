import CoreLocation
import Foundation

/// Fast binary parser for OGC Well-Known Binary (WKB) format geometries.
///
/// Supports LineString (type 2) and MultiLineString (type 5) with both
/// Little-Endian and Big-Endian byte orders.
enum WKBDecoder {
    enum WKBError: Error, Equatable, Sendable {
        case dataTooShort
        case unsupportedGeometryType(UInt32)
        case invalidCoordinateCount
        case bufferUnderflow
    }

    struct DecodedGeometry: Sendable {
        var geometry: ParkingGeometry
        var coordinateParts: [[CLLocationCoordinate2D]]
    }

    private enum WKBType: UInt32 {
        case lineString = 2
        case multiLineString = 5
    }

    nonisolated static func decode(_ data: Data) throws -> DecodedGeometry {
        try data.withUnsafeBytes { rawBuffer in
            guard let ptr = rawBuffer.baseAddress else {
                throw WKBError.dataTooShort
            }
            var cursor = 0
            let total = rawBuffer.count
            return try decodeGeometry(ptr: ptr, cursor: &cursor, total: total)
        }
    }

    nonisolated private static func decodeGeometry(
        ptr: UnsafeRawPointer,
        cursor: inout Int,
        total: Int
    ) throws -> DecodedGeometry {
        guard cursor + 5 <= total else {
            throw WKBError.dataTooShort
        }

        let isLittleEndian = ptr.loadUnaligned(fromByteOffset: cursor, as: UInt8.self) == 1
        cursor += 1

        let rawType: UInt32
        if isLittleEndian {
            rawType = UInt32(littleEndian: ptr.loadUnaligned(fromByteOffset: cursor, as: UInt32.self))
        } else {
            rawType = UInt32(bigEndian: ptr.loadUnaligned(fromByteOffset: cursor, as: UInt32.self))
        }
        cursor += 4

        // Mask off 2D / 3D / SRID flags if present (standard 2D geometries are 2 and 5)
        let baseType = rawType & 0xFF

        switch baseType {
        case WKBType.lineString.rawValue:
            let points = try decodeLineStringPoints(
                ptr: ptr,
                cursor: &cursor,
                total: total,
                isLittleEndian: isLittleEndian
            )
            let coords = points.map { CLLocationCoordinate2D(latitude: $0.1, longitude: $0.0) }
            let rawCoords = points.map { [$0.0, $0.1] }
            return DecodedGeometry(
                geometry: .lineString(coordinates: rawCoords),
                coordinateParts: [coords]
            )

        case WKBType.multiLineString.rawValue:
            guard cursor + 4 <= total else {
                throw WKBError.dataTooShort
            }
            let numLineStrings: UInt32
            if isLittleEndian {
                numLineStrings = UInt32(littleEndian: ptr.loadUnaligned(fromByteOffset: cursor, as: UInt32.self))
            } else {
                numLineStrings = UInt32(bigEndian: ptr.loadUnaligned(fromByteOffset: cursor, as: UInt32.self))
            }
            cursor += 4

            var partsCoords: [[CLLocationCoordinate2D]] = []
            var partsRaw: [[[Double]]] = []
            partsCoords.reserveCapacity(Int(numLineStrings))
            partsRaw.reserveCapacity(Int(numLineStrings))

            for _ in 0..<numLineStrings {
                let subGeom = try decodeGeometry(ptr: ptr, cursor: &cursor, total: total)
                if let partCoords = subGeom.coordinateParts.first {
                    partsCoords.append(partCoords)
                }
                switch subGeom.geometry {
                case .lineString(let coords):
                    partsRaw.append(coords)
                case .multiLineString(let multi):
                    partsRaw.append(contentsOf: multi)
                }
            }

            return DecodedGeometry(
                geometry: .multiLineString(coordinates: partsRaw),
                coordinateParts: partsCoords
            )

        default:
            throw WKBError.unsupportedGeometryType(rawType)
        }
    }

    nonisolated private static func decodeLineStringPoints(
        ptr: UnsafeRawPointer,
        cursor: inout Int,
        total: Int,
        isLittleEndian: Bool
    ) throws -> [(Double, Double)] {
        guard cursor + 4 <= total else {
            throw WKBError.dataTooShort
        }

        let numPoints: UInt32
        if isLittleEndian {
            numPoints = UInt32(littleEndian: ptr.loadUnaligned(fromByteOffset: cursor, as: UInt32.self))
        } else {
            numPoints = UInt32(bigEndian: ptr.loadUnaligned(fromByteOffset: cursor, as: UInt32.self))
        }
        cursor += 4

        let count = Int(numPoints)
        let byteSize = count * 16
        guard cursor + byteSize <= total else {
            throw WKBError.dataTooShort
        }

        var points: [(Double, Double)] = []
        points.reserveCapacity(count)

        for _ in 0..<count {
            let xBits: UInt64
            let yBits: UInt64
            if isLittleEndian {
                xBits = UInt64(littleEndian: ptr.loadUnaligned(fromByteOffset: cursor, as: UInt64.self))
                yBits = UInt64(littleEndian: ptr.loadUnaligned(fromByteOffset: cursor + 8, as: UInt64.self))
            } else {
                xBits = UInt64(bigEndian: ptr.loadUnaligned(fromByteOffset: cursor, as: UInt64.self))
                yBits = UInt64(bigEndian: ptr.loadUnaligned(fromByteOffset: cursor + 8, as: UInt64.self))
            }
            cursor += 16

            let x = Double(bitPattern: xBits)
            let y = Double(bitPattern: yBits)
            points.append((x, y))
        }

        return points
    }
}
