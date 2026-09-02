import CoreLocation
import Foundation

/// Snapshot-local feature identity from `_id`, or `idx:<n>` when `_id` is missing.
nonisolated struct FeatureID: Hashable, Codable, Sendable, Comparable {
    let rawValue: String

    nonisolated init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    nonisolated init(_ rawValue: Int) {
        self.rawValue = String(rawValue)
    }

    nonisolated static func fromSourceID(_ sourceID: String?, index: Int) -> FeatureID {
        if let sourceID, !sourceID.isEmpty {
            return FeatureID(sourceID)
        }
        return FeatureID("idx:\(index)")
    }

    nonisolated static func < (lhs: FeatureID, rhs: FeatureID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Stable source-derived key: Highway|Rule|Side|category|max
nonisolated struct RuleKey: Hashable, Codable, Sendable {
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

nonisolated enum ParkingGeometry: Sendable, Equatable, Codable {
    case lineString(coordinates: [[Double]])
    case multiLineString(coordinates: [[[Double]]])

    nonisolated var typeName: String {
        switch self {
        case .lineString: return "LineString"
        case .multiLineString: return "MultiLineString"
        }
    }
}

nonisolated struct ParkingProperties: Sendable, Equatable, Codable {
    var highway: String
    var rule: String
    var scheduleCategory: String
    var side: String
    var max: String?
    var schedule: Schedule?
    var maxMinutes: Int?
    var disjointBlock: Bool?

    var sourceID: String?
    var sideMode: String?
    var curbGeometryMethod: String?
    var curbConfidence: Double?
    var curbCoverage: Double?
    var medianOffsetM: Double?
    var curbOverride: Bool?
    var curbWarnings: [String]?
    var centrelineIDs: [Int]?
    var roadEdgeObjectIDs: [Int]?
    var centrelineConstruction: String?
    var mergeDroppedComponent: Bool?

    // Pipeline enhancement data fields
    var isSnowRoute: Bool?
    var streetcarCorridor: Bool?
    var formerMunicipality: String?
    var regionalWinterRule: String?
    var permitAreaID: String?
    var permitParkingActive: Bool?
    var hasHydrant: Bool?
    var hydrantCount: Int?
    var hydrantSetbackM: Double?

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
        case sourceID = "_id"
        case sideMode = "side_mode"
        case curbGeometryMethod = "curb_geometry_method"
        case curbConfidence = "curb_confidence"
        case curbCoverage = "curb_coverage"
        case medianOffsetM = "median_offset_m"
        case curbOverride = "curb_override"
        case curbWarnings = "curb_warnings"
        case centrelineIDs = "centreline_ids"
        case roadEdgeObjectIDs = "road_edge_object_ids"
        case centrelineConstruction = "centreline_construction"
        case mergeDroppedComponent = "merge_dropped_component"
        case isSnowRoute = "is_snow_route"
        case streetcarCorridor = "streetcar_corridor"
        case formerMunicipality = "former_municipality"
        case regionalWinterRule = "regional_winter_rule"
        case permitAreaID = "permit_area_id"
        case permitParkingActive = "permit_parking_active"
        case hasHydrant = "has_hydrant"
        case hydrantCount = "hydrant_count"
        case hydrantSetbackM = "hydrant_setback_m"
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
        sourceID: String? = nil,
        sideMode: String? = nil,
        curbGeometryMethod: String? = nil,
        curbConfidence: Double? = nil,
        curbCoverage: Double? = nil,
        medianOffsetM: Double? = nil,
        curbOverride: Bool? = nil,
        curbWarnings: [String]? = nil,
        centrelineIDs: [Int]? = nil,
        roadEdgeObjectIDs: [Int]? = nil,
        centrelineConstruction: String? = nil,
        mergeDroppedComponent: Bool? = nil,
        isSnowRoute: Bool? = nil,
        streetcarCorridor: Bool? = nil,
        formerMunicipality: String? = nil,
        regionalWinterRule: String? = nil,
        permitAreaID: String? = nil,
        permitParkingActive: Bool? = nil,
        hasHydrant: Bool? = nil,
        hydrantCount: Int? = nil,
        hydrantSetbackM: Double? = nil,
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
        self.sourceID = sourceID
        self.sideMode = sideMode
        self.curbGeometryMethod = curbGeometryMethod
        self.curbConfidence = curbConfidence
        self.curbCoverage = curbCoverage
        self.medianOffsetM = medianOffsetM
        self.curbOverride = curbOverride
        self.curbWarnings = curbWarnings
        self.centrelineIDs = centrelineIDs
        self.roadEdgeObjectIDs = roadEdgeObjectIDs
        self.centrelineConstruction = centrelineConstruction
        self.mergeDroppedComponent = mergeDroppedComponent
        self.isSnowRoute = isSnowRoute
        self.streetcarCorridor = streetcarCorridor
        self.formerMunicipality = formerMunicipality
        self.regionalWinterRule = regionalWinterRule
        self.permitAreaID = permitAreaID
        self.permitParkingActive = permitParkingActive
        self.hasHydrant = hasHydrant
        self.hydrantCount = hydrantCount
        self.hydrantSetbackM = hydrantSetbackM
        self.polarity = polarity
        self.visible = visible
        self.unparsed = unparsed
        self.partial = partial
        self.failed = failed
        self.featureKey = featureKey
        self.severity = severity
    }

    /// Dimmed overlay for unresolved / ambiguous curb placement; never hidden.
    nonisolated var hasUncertainCurbPlacement: Bool {
        if curbGeometryMethod == "centerline_unresolved" { return true }
        let warnings = curbWarnings ?? []
        return warnings.contains("SIDE_AMBIGUOUS") || warnings.contains("CENTERLINE_FALLBACK")
    }
}

nonisolated struct ParkingFeature: Sendable, Equatable, Identifiable {
    var id: FeatureID
    var geometry: ParkingGeometry
    var properties: ParkingProperties
    var coordinateParts: [[CLLocationCoordinate2D]]

    nonisolated init(
        id: FeatureID,
        geometry: ParkingGeometry,
        properties: ParkingProperties,
        coordinateParts: [[CLLocationCoordinate2D]]? = nil
    ) {
        self.id = id
        self.geometry = geometry
        self.properties = properties
        self.coordinateParts = coordinateParts ?? CurbGeometry.mapCoordinateParts(geometry)
    }

    nonisolated static func == (lhs: ParkingFeature, rhs: ParkingFeature) -> Bool {
        lhs.id == rhs.id && lhs.geometry == rhs.geometry && lhs.properties == rhs.properties
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

nonisolated struct ParkingFeatureCollection: Sendable, Equatable {
    var features: [ParkingFeature]

    nonisolated init(features: [ParkingFeature]) {
        self.features = features
    }
}
