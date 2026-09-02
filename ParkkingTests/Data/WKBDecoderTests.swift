import CoreLocation
import Foundation
import Testing
@testable import Parkking

@Suite("WKBDecoder Tests")
struct WKBDecoderTests {
    @Test("Decodes Little-Endian LineString")
    func decodeLittleEndianLineString() throws {
        // LineString with 2 points: (-79.4, 43.65) to (-79.39, 43.66)
        var data = Data()
        // Byte order: 1 (Little Endian)
        data.append(contentsOf: [UInt8(1)])
        // Type: 2 (LineString) uint32 LE
        var typeLE: UInt32 = 2
        data.append(Data(bytes: &typeLE, count: 4))
        // NumPoints: 2 uint32 LE
        var countLE: UInt32 = 2
        data.append(Data(bytes: &countLE, count: 4))
        // Point 1: (-79.4, 43.65)
        var x1 = -79.4
        var y1 = 43.65
        data.append(Data(bytes: &x1, count: 8))
        data.append(Data(bytes: &y1, count: 8))
        // Point 2: (-79.39, 43.66)
        var x2 = -79.39
        var y2 = 43.66
        data.append(Data(bytes: &x2, count: 8))
        data.append(Data(bytes: &y2, count: 8))

        let decoded = try WKBDecoder.decode(data)
        guard case .lineString(let coords) = decoded.geometry else {
            Issue.record("Expected LineString")
            return
        }
        #expect(coords.count == 2)
        #expect(coords[0][0] == -79.4)
        #expect(coords[0][1] == 43.65)
        #expect(coords[1][0] == -79.39)
        #expect(coords[1][1] == 43.66)

        #expect(decoded.coordinateParts.count == 1)
        #expect(decoded.coordinateParts[0].count == 2)
        #expect(decoded.coordinateParts[0][0].latitude == 43.65)
        #expect(decoded.coordinateParts[0][0].longitude == -79.4)
    }

    @Test("Decodes Big-Endian LineString")
    func decodeBigEndianLineString() throws {
        var data = Data()
        // Byte order: 0 (Big Endian)
        data.append(contentsOf: [UInt8(0)])
        // Type: 2 (LineString) uint32 BE
        var typeBE = UInt32(2).bigEndian
        data.append(Data(bytes: &typeBE, count: 4))
        // NumPoints: 1 uint32 BE
        var countBE = UInt32(1).bigEndian
        data.append(Data(bytes: &countBE, count: 4))
        // Point 1: (-79.5, 43.7) in BE
        var xBits = (-79.5).bitPattern.bigEndian
        var yBits = (43.7).bitPattern.bigEndian
        data.append(Data(bytes: &xBits, count: 8))
        data.append(Data(bytes: &yBits, count: 8))

        let decoded = try WKBDecoder.decode(data)
        guard case .lineString(let coords) = decoded.geometry else {
            Issue.record("Expected LineString")
            return
        }
        #expect(coords.count == 1)
        #expect(coords[0][0] == -79.5)
        #expect(coords[0][1] == 43.7)
    }

    @Test("Decodes MultiLineString")
    func decodeMultiLineString() throws {
        var data = Data()
        // Byte order: 1 (Little Endian)
        data.append(contentsOf: [UInt8(1)])
        // Type: 5 (MultiLineString) uint32 LE
        var typeLE: UInt32 = 5
        data.append(Data(bytes: &typeLE, count: 4))
        // NumLineStrings: 2 uint32 LE
        var numPartsLE: UInt32 = 2
        data.append(Data(bytes: &numPartsLE, count: 4))

        // Part 1: LineString with 1 pt
        data.append(contentsOf: [UInt8(1)])
        var lineTypeLE: UInt32 = 2
        data.append(Data(bytes: &lineTypeLE, count: 4))
        var count1LE: UInt32 = 1
        data.append(Data(bytes: &count1LE, count: 4))
        var x1 = -79.1
        var y1 = 43.1
        data.append(Data(bytes: &x1, count: 8))
        data.append(Data(bytes: &y1, count: 8))

        // Part 2: LineString with 1 pt
        data.append(contentsOf: [UInt8(1)])
        data.append(Data(bytes: &lineTypeLE, count: 4))
        var count2LE: UInt32 = 1
        data.append(Data(bytes: &count2LE, count: 4))
        var x2 = -79.2
        var y2 = 43.2
        data.append(Data(bytes: &x2, count: 8))
        data.append(Data(bytes: &y2, count: 8))

        let decoded = try WKBDecoder.decode(data)
        guard case .multiLineString(let parts) = decoded.geometry else {
            Issue.record("Expected MultiLineString")
            return
        }
        #expect(parts.count == 2)
        #expect(decoded.coordinateParts.count == 2)
    }

    @Test("Errors on empty data or truncated buffer")
    func decodeErrorHandling() {
        #expect(throws: WKBDecoder.WKBError.dataTooShort) {
            try WKBDecoder.decode(Data())
        }
        #expect(throws: WKBDecoder.WKBError.dataTooShort) {
            try WKBDecoder.decode(Data([1, 2, 0]))
        }
    }
}
