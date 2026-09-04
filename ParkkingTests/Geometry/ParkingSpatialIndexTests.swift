import Testing
@testable import Parkking

@MainActor
@Suite("ParkingSpatialIndex")
struct ParkingSpatialIndexTests {
    private var collection: ParkingFeatureCollection {
        ParkingFeatureCollection(
            features: [
                ParkingFeature(
                    id: FeatureID(0),
                    geometry: .lineString(coordinates: [[-79.4, 43.65], [-79.401, 43.651]]),
                    properties: ParkingProperties(
                        highway: "A",
                        rule: "Anytime",
                        scheduleCategory: "no_parking",
                        side: "North",
                        max: nil,
                        schedule: Schedule(
                            v: 1,
                            status: .anytime,
                            source: "Anytime",
                            windows: []
                        )
                    )
                ),
                ParkingFeature(
                    id: FeatureID(1),
                    geometry: .lineString(coordinates: [[-79.5, 43.7], [-79.501, 43.701]]),
                    properties: ParkingProperties(
                        highway: "B",
                        rule: "Anytime",
                        scheduleCategory: "no_parking",
                        side: "South",
                        max: nil,
                        schedule: Schedule(
                            v: 1,
                            status: .anytime,
                            source: "Anytime",
                            windows: []
                        )
                    )
                ),
            ]
        )
    }

    private var slot: Slot {
        Slot(dayOfWeek: 2, minuteOfDay: 900, month: 5, dayOfMonth: 20, year: 2025)
    }

    @Test("queries only features intersecting a bbox")
    func queriesOnlyFeaturesIntersectingBBox() {
        let index = ParkingSpatialIndex(collection: collection)
        let near = index.queryBBox(
            BBox(minLng: -79.41, minLat: 43.64, maxLng: -79.39, maxLat: 43.66)
        )
        #expect(near.count == 1)
        #expect(near[0].properties.highway == "A")
    }

    @Test("returns all features for selection")
    func returnsAllFeaturesForSelection() {
        let index = ParkingSpatialIndex(collection: collection)
        #expect(index.allFeatures().count == 2)
    }

    @Test("indexed vs brute force tap parity within tap radius")
    func indexedVsBruteForceTapParityWithinTapRadius() {
        // Dense cluster near the tap plus a far decoy outside the search pad.
        var features: [ParkingFeature] = []
        for i in 0..<12 {
            let lng = -79.400 + Double(i) * 0.00015
            features.append(
                ParkingFeature(
                    id: FeatureID(i),
                    geometry: .lineString(coordinates: [
                        [lng, 43.650],
                        [lng + 0.0004, 43.6501],
                    ]),
                    properties: ParkingProperties(
                        highway: "Local \(i)",
                        rule: "rule \(i)",
                        scheduleCategory: "no_parking",
                        side: i % 2 == 0 ? "North" : "South",
                        max: nil
                    )
                )
            )
        }
        features.append(
            ParkingFeature(
                id: FeatureID(99),
                geometry: .lineString(coordinates: [[-79.55, 43.8], [-79.551, 43.801]]),
                properties: ParkingProperties(
                    highway: "Far",
                    rule: "far",
                    scheduleCategory: "no_parking",
                    side: "East",
                    max: nil
                )
            )
        )

        let collection = ParkingFeatureCollection(features: features)
        let index = ParkingSpatialIndex(collection: collection)
        let point = LngLat(lng: -79.3998, lat: 43.65005)
        let radius = CurbSelection.tapMaxDistanceMeters

        let padDeg = CurbGeometry.degreesPad(forMeters: radius, atLatitude: point.lat)
        let bbox = BBox(
            minLng: point.lng,
            minLat: point.lat,
            maxLng: point.lng,
            maxLat: point.lat
        )
        let indexedSubset = index.queryBBox(bbox, padDeg: padDeg)
        let indexedCandidates = CurbSelection.findNearestCurbCandidates(
            features: indexedSubset,
            point: point,
            maxDistanceMeters: radius
        )
        let bruteCandidates = CurbSelection.findNearestCurbCandidates(
            features: features,
            point: point,
            maxDistanceMeters: radius
        )

        #expect(indexedCandidates.count > 0)
        #expect(indexedCandidates.count == bruteCandidates.count)
        #expect(
            indexedCandidates.map(\.featureKey) == bruteCandidates.map(\.featureKey)
        )
        for (a, b) in zip(indexedCandidates, bruteCandidates) {
            #expect(abs(a.distanceMeters - b.distanceMeters) < 1e-9)
        }
    }
}

@MainActor
@Suite("enrichFeaturesSubset")
struct EnrichFeaturesSubsetTests {
    private var collection: ParkingFeatureCollection {
        ParkingFeatureCollection(
            features: [
                ParkingFeature(
                    id: FeatureID(0),
                    geometry: .lineString(coordinates: [[-79.4, 43.65], [-79.401, 43.651]]),
                    properties: ParkingProperties(
                        highway: "A",
                        rule: "Anytime",
                        scheduleCategory: "no_parking",
                        side: "North",
                        max: nil,
                        schedule: Schedule(
                            v: 1,
                            status: .anytime,
                            source: "Anytime",
                            windows: []
                        )
                    )
                ),
            ]
        )
    }

    private var slot: Slot {
        Slot(dayOfWeek: 2, minuteOfDay: 900, month: 5, dayOfMonth: 20, year: 2025)
    }

    @Test("adds polarity, feature key, and severity")
    func addsPolarityFeatureKeyAndSeverity() {
        let enriched = ParkingSpatialIndex.enrichFeaturesSubset(
            collection.features,
            slot: slot,
            includeUnknown: true,
            endMinuteOfDay: nil
        )
        #expect(enriched.features[0].properties.featureKey != nil)
        #expect(enriched.features[0].properties.featureKey?.isEmpty == false)
        #expect(enriched.features[0].properties.polarity == .restricted)
        #expect(enriched.features[0].properties.severity == 2)
    }

    @Test("suppresses inactive winter rule from enriched features so no line renders")
    func suppressesInactiveWinterRuleFromEnrichedFeatures() {
        let winterFeature = ParkingFeature(
            id: FeatureID("winter_devon"),
            geometry: .lineString(coordinates: [[-79.4, 43.65], [-79.401, 43.651]]),
            properties: ParkingProperties(
                highway: "Devon Rd",
                rule: "Anytime, from Dec. 1 of one year to Mar. 31 of the next following year, inclusive",
                scheduleCategory: "no_parking",
                side: "North",
                schedule: Schedule(
                    v: 1,
                    status: .ok,
                    source: "Anytime, from Dec. 1 of one year to Mar. 31 of the next following year, inclusive",
                    windows: [
                        TimeWindow(
                            days: [0, 1, 2, 3, 4, 5, 6],
                            startMinute: 0,
                            endMinute: 1439,
                            calendar: ScheduleCalendar(
                                monthRanges: [CalendarMonthRange(startMonth: 12, startDay: 1, endMonth: 3, endDay: 31)]
                            )
                        )
                    ]
                )
            )
        )

        // Slot in May (outside winter)
        let summerSlot = Slot(dayOfWeek: 2, minuteOfDay: 900, month: 5, dayOfMonth: 20, year: 2025)
        let enrichedSummer = ParkingSpatialIndex.enrichFeaturesSubset(
            [winterFeature],
            slot: summerSlot,
            includeUnknown: true
        )
        #expect(enrichedSummer.features.isEmpty)

        // Slot in January (inside winter)
        let winterSlot = Slot(dayOfWeek: 2, minuteOfDay: 900, month: 1, dayOfMonth: 15, year: 2025)
        let enrichedWinter = ParkingSpatialIndex.enrichFeaturesSubset(
            [winterFeature],
            slot: winterSlot,
            includeUnknown: true
        )
        #expect(enrichedWinter.features.count == 1)
        #expect(enrichedWinter.features[0].properties.polarity == .restricted)
    }

    @Test("suppresses inactive snow route from enriched features when emergency not declared")
    func suppressesInactiveSnowRouteFromEnrichedFeatures() {
        let snowFeature = ParkingFeature(
            id: FeatureID("snow_danforth"),
            geometry: .lineString(coordinates: [[-79.4, 43.65], [-79.401, 43.651]]),
            properties: ParkingProperties(
                highway: "Danforth Ave",
                rule: "Major Snow Storm Conditions",
                scheduleCategory: "snow_route",
                side: "North",
                schedule: Schedule(
                    v: 1,
                    status: .conditional,
                    source: "Major Snow Storm Conditions",
                    condition: "major_snowstorm_declared",
                    isSnowRoute: true
                ),
                isSnowRoute: true
            )
        )

        let calmSlot = Slot(dayOfWeek: 2, minuteOfDay: 900, month: 5, dayOfMonth: 20, majorSnowstorm: false)
        let enrichedCalm = ParkingSpatialIndex.enrichFeaturesSubset(
            [snowFeature],
            slot: calmSlot,
            includeUnknown: true
        )
        #expect(enrichedCalm.features.isEmpty)

        let declaredSlot = Slot(dayOfWeek: 2, minuteOfDay: 900, month: 5, dayOfMonth: 20, majorSnowstorm: true)
        let enrichedDeclared = ParkingSpatialIndex.enrichFeaturesSubset(
            [snowFeature],
            slot: declaredSlot,
            includeUnknown: true
        )
        #expect(enrichedDeclared.features.count == 1)
        #expect(enrichedDeclared.features[0].properties.polarity == FilterPolarity.restricted)
    }
}

@MainActor
@Suite("severityOrder")
struct SeverityOrderTests {
    @Test("orders allowed, unclear, then restricted")
    func ordersAllowedUnclearThenRestricted() {
        #expect(ParkingSpatialIndex.severityOrder(polarity: .inactive, unparsed: false) == 0)
        #expect(ParkingSpatialIndex.severityOrder(polarity: .unknown, unparsed: true) == 1)
        #expect(ParkingSpatialIndex.severityOrder(polarity: .restricted, unparsed: false) == 2)

        let sorted = ParkingSpatialIndex.sortFeaturesBySeverity([
            ParkingFeature(
                id: FeatureID(0),
                geometry: .lineString(coordinates: [[0, 0], [1, 1]]),
                properties: ParkingProperties(
                    highway: "r",
                    rule: "r",
                    scheduleCategory: "no_parking",
                    side: "N",
                    max: nil,
                    polarity: .restricted
                )
            ),
            ParkingFeature(
                id: FeatureID(1),
                geometry: .lineString(coordinates: [[0, 0], [1, 1]]),
                properties: ParkingProperties(
                    highway: "a",
                    rule: "a",
                    scheduleCategory: "no_parking",
                    side: "N",
                    max: nil,
                    polarity: .inactive
                )
            ),
        ])
        #expect(sorted[0].properties.highway == "a")
        #expect(sorted[1].properties.highway == "r")
    }
}
