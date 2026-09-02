import Foundation

/// Geographic bounding box metadata for the dataset.
nonisolated struct ManifestBoundingBox: Sendable, Codable, Equatable {
    var minLng: Double
    var minLat: Double
    var maxLng: Double
    var maxLat: Double

    enum CodingKeys: String, CodingKey {
        case minLng = "min_lng"
        case minLat = "min_lat"
        case maxLng = "max_lng"
        case maxLat = "max_lat"
    }
}

/// Provenance metadata for the bundled Toronto curb database snapshot.
nonisolated struct ParkingDataManifest: Sendable, Codable, Equatable {
    var artifact: String
    var format: String
    var schemaVersion: Int
    var pipelineVersion: String
    var featureCount: Int
    var byteSize: Int
    var sha256: String
    var boundingBox: ManifestBoundingBox?
    var generatedAt: String?
    var sourceRepo: String?
    var sourceRevision: String?

    var filename: String { artifact }
    var scheduleSchemaVersion: Int { schemaVersion }

    enum CodingKeys: String, CodingKey {
        case artifact
        case format
        case schemaVersion = "schema_version"
        case pipelineVersion = "pipeline_version"
        case featureCount = "feature_count"
        case fileSizeBytes = "file_size_bytes"
        case byteSize
        case sha256
        case boundingBox = "bounding_box"
        case generatedAt = "generated_at"
        case sourceRepo
        case sourceRevision
        case legacyFilename = "filename"
        case legacyScheduleSchemaVersion = "scheduleSchemaVersion"
    }

    nonisolated init(
        artifact: String = "parking_map.sqlite",
        format: String = "sqlite3_rtree_wkb",
        schemaVersion: Int = 1,
        pipelineVersion: String = "0.1.0",
        featureCount: Int = 24_669,
        byteSize: Int = 22_355_968,
        sha256: String = "2c5a9af95b0d0559d1d889964f5d9f2da1144729266e1d3b0d6da23dfacd3ece",
        boundingBox: ManifestBoundingBox? = nil,
        generatedAt: String? = nil,
        sourceRepo: String? = "parking-pipeline",
        sourceRevision: String? = nil
    ) {
        self.artifact = artifact
        self.format = format
        self.schemaVersion = schemaVersion
        self.pipelineVersion = pipelineVersion
        self.featureCount = featureCount
        self.byteSize = byteSize
        self.sha256 = sha256
        self.boundingBox = boundingBox
        self.generatedAt = generatedAt
        self.sourceRepo = sourceRepo
        self.sourceRevision = sourceRevision
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.artifact = try container.decodeIfPresent(String.self, forKey: .artifact)
            ?? container.decodeIfPresent(String.self, forKey: .legacyFilename)
            ?? "parking_map.sqlite"
        self.format = try container.decodeIfPresent(String.self, forKey: .format) ?? "sqlite3_rtree_wkb"
        self.schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
            ?? container.decodeIfPresent(Int.self, forKey: .legacyScheduleSchemaVersion)
            ?? 1
        self.pipelineVersion = try container.decodeIfPresent(String.self, forKey: .pipelineVersion) ?? "0.1.0"
        self.featureCount = try container.decodeIfPresent(Int.self, forKey: .featureCount) ?? 0
        self.byteSize = try container.decodeIfPresent(Int.self, forKey: .fileSizeBytes)
            ?? container.decodeIfPresent(Int.self, forKey: .byteSize)
            ?? 0
        self.sha256 = try container.decodeIfPresent(String.self, forKey: .sha256) ?? ""
        self.boundingBox = try container.decodeIfPresent(ManifestBoundingBox.self, forKey: .boundingBox)
        self.generatedAt = try container.decodeIfPresent(String.self, forKey: .generatedAt)
        self.sourceRepo = try container.decodeIfPresent(String.self, forKey: .sourceRepo)
        self.sourceRevision = try container.decodeIfPresent(String.self, forKey: .sourceRevision)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(artifact, forKey: .artifact)
        try container.encode(format, forKey: .format)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(pipelineVersion, forKey: .pipelineVersion)
        try container.encode(featureCount, forKey: .featureCount)
        try container.encode(byteSize, forKey: .fileSizeBytes)
        try container.encode(sha256, forKey: .sha256)
        try container.encodeIfPresent(boundingBox, forKey: .boundingBox)
        try container.encodeIfPresent(generatedAt, forKey: .generatedAt)
        try container.encodeIfPresent(sourceRepo, forKey: .sourceRepo)
        try container.encodeIfPresent(sourceRevision, forKey: .sourceRevision)
    }

    nonisolated static let bundled = ParkingDataManifest()

    nonisolated static func load(from bundle: Bundle = .main) throws -> ParkingDataManifest {
        if let url = bundle.url(
            forResource: "parking-data-manifest",
            withExtension: "json",
            subdirectory: "Data"
        ) ?? bundle.url(forResource: "parking-data-manifest", withExtension: "json")
            ?? bundle.url(forResource: "parking_data_manifest", withExtension: "json", subdirectory: "Data")
            ?? bundle.url(forResource: "parking_data_manifest", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let manifest = try? JSONDecoder().decode(ParkingDataManifest.self, from: data)
        {
            return manifest
        }
        return .bundled
    }
}
