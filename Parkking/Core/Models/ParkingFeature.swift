import Foundation

/// Snapshot-local feature identity assigned by decode order.
struct FeatureID: Hashable, Codable, Sendable, Comparable {
    let rawValue: Int

    nonisolated init(_ rawValue: Int) {
        self.rawValue = rawValue
    }

    nonisolated static func < (lhs: FeatureID, rhs: FeatureID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Stable source-derived key: Highway|Rule|Side|category|max
struct RuleKey: Hashable, Codable, Sendable {
    let rawValue: String

    nonisolated init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    nonisolated init(
        highway: String,
        rule: String,
        side: String,
        scheduleCategory: String,
        max: String?
    ) {
        self.rawValue = [
            highway,
            rule,
            side,
            scheduleCategory,
            max ?? "",
        ].joined(separator: "|")
    }
}

enum ParkingGeometry: Sendable, Equatable, Codable {
    case lineString(coordinates: [[Double]])
    case multiLineString(coordinates: [[[Double]]])

    nonisolated var typeName: String {
        switch self {
        case .lineString: return "LineString"
        case .multiLineString: return "MultiLineString"
        }
    }
}

struct ParkingProperties: Sendable, Equatable, Codable {
    var highway: String
    var rule: String
    var scheduleCategory: String
    var side: String
    var max: String?
    var schedule: Schedule?
    var maxMinutes: Int?
    var disjointBlock: Bool?

    // Client-only enrichment fields
    var polarity: FilterPolarity?
    var visible: Bool?
    var unparsed: Bool?
    var partial: Bool?
    var failed: Bool?
    var featureKey: String?
    var severity: Int?

    enum CodingKeys: String, CodingKey {
        case highway = "Highway"
        case rule = "Rule"
        case scheduleCategory = "schedule_category"
        case side = "Side"
        case max
        case schedule
        case maxMinutes
        case disjointBlock = "disjoint_block"
        case polarity = "_polarity"
        case visible = "_visible"
        case unparsed = "_unparsed"
        case partial = "_partial"
        case failed = "_failed"
        case featureKey = "_featureKey"
        case severity = "_severity"
    }

    nonisolated init(
        highway: String,
        rule: String,
        scheduleCategory: String,
        side: String,
        max: String? = nil,
        schedule: Schedule? = nil,
        maxMinutes: Int? = nil,
        disjointBlock: Bool? = nil,
        polarity: FilterPolarity? = nil,
        visible: Bool? = nil,
        unparsed: Bool? = nil,
        partial: Bool? = nil,
        failed: Bool? = nil,
        featureKey: String? = nil,
        severity: Int? = nil
    ) {
        self.highway = highway
        self.rule = rule
        self.scheduleCategory = scheduleCategory
        self.side = side
        self.max = max
        self.schedule = schedule
        self.maxMinutes = maxMinutes
        self.disjointBlock = disjointBlock
        self.polarity = polarity
        self.visible = visible
        self.unparsed = unparsed
        self.partial = partial
        self.failed = failed
        self.featureKey = featureKey
        self.severity = severity
    }
}

struct ParkingFeature: Sendable, Equatable, Identifiable {
    var id: FeatureID
    var geometry: ParkingGeometry
    var properties: ParkingProperties

    nonisolated init(id: FeatureID, geometry: ParkingGeometry, properties: ParkingProperties) {
        self.id = id
        self.geometry = geometry
        self.properties = properties
    }

    nonisolated var ruleKey: RuleKey {
        RuleKey(
            highway: properties.highway,
            rule: properties.rule,
            side: properties.side,
            scheduleCategory: properties.scheduleCategory,
            max: properties.max
        )
    }
}

struct ParkingFeatureCollection: Sendable, Equatable {
    var features: [ParkingFeature]

    nonisolated init(features: [ParkingFeature]) {
        self.features = features
    }
}
