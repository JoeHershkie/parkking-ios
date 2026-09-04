import CoreLocation
import Testing
@testable import Parkking

@MainActor
@Suite("CurbOverlapResolver")
struct CurbOverlapResolverTests {
    private func lineFeature(
        id: String,
        street: String,
        side: String,
        category: String,
        polarity: FilterPolarity,
        coords: [[Double]],
        unparsed: Bool = false,
        severity: Int? = nil,
        schedule: Schedule? = nil
    ) -> ParkingFeature {
        let sev = severity ?? (polarity == .restricted || polarity == .notPermitted ? 2 : (polarity == .unknown || polarity == .partial ? 1 : 0))
        return ParkingFeature(
            id: FeatureID(id),
            geometry: .lineString(coordinates: coords),
            properties: ParkingProperties(
                highway: street,
                rule: "Rule \(id)",
                scheduleCategory: category,
                side: side,
                max: nil,
                schedule: schedule,
                sourceID: id,
                polarity: polarity,
                unparsed: unparsed,
                severity: sev
            )
        )
    }

    @Test("Precedence scores match 6-tier hierarchy")
    func precedenceScoresMatchHierarchy() {
        let noStopping = lineFeature(
            id: "1",
            street: "Queen St",
            side: "North",
            category: "no_stopping",
            polarity: .restricted,
            coords: [[-79.4, 43.65], [-79.401, 43.65]]
        )
        let noStanding = lineFeature(
            id: "2",
            street: "Queen St",
            side: "North",
            category: "no_standing",
            polarity: .restricted,
            coords: [[-79.4, 43.65], [-79.401, 43.65]]
        )
        let permitGreen = lineFeature(
            id: "3",
            street: "Queen St",
            side: "North",
            category: "restricted_periods",
            polarity: .permitted,
            coords: [[-79.4, 43.65], [-79.401, 43.65]]
        )
        let noParking = lineFeature(
            id: "4",
            street: "Queen St",
            side: "North",
            category: "no_parking",
            polarity: .restricted,
            coords: [[-79.4, 43.65], [-79.401, 43.65]]
        )
        let orangeUnclear = lineFeature(
            id: "5",
            street: "Queen St",
            side: "North",
            category: "no_parking",
            polarity: .unknown,
            coords: [[-79.4, 43.65], [-79.401, 43.65]],
            unparsed: true
        )
        let inactiveGreen = lineFeature(
            id: "6",
            street: "Queen St",
            side: "North",
            category: "no_parking",
            polarity: .inactive,
            coords: [[-79.4, 43.65], [-79.401, 43.65]]
        )

        let snowRoute = lineFeature(
            id: "7",
            street: "Queen St",
            side: "North",
            category: "snow_route",
            polarity: .restricted,
            coords: [[-79.4, 43.65], [-79.401, 43.65]]
        )

        #expect(CurbOverlapResolver.precedenceScore(feature: noStopping) == 50)
        #expect(CurbOverlapResolver.precedenceScore(feature: snowRoute) == 45)
        #expect(CurbOverlapResolver.precedenceScore(feature: noStanding) == 40)
        #expect(CurbOverlapResolver.precedenceScore(feature: permitGreen) == 30)
        #expect(CurbOverlapResolver.precedenceScore(feature: noParking) == 20)
        #expect(CurbOverlapResolver.precedenceScore(feature: orangeUnclear) == 10)
        #expect(CurbOverlapResolver.precedenceScore(feature: inactiveGreen) == 0)
    }

    @Test("Inactive green overlapped by active red: red wins and green is sliced in middle")
    func inactiveGreenOverlappedByActiveRedSlicesGreen() {
        // Long green segment (approx 80m from -79.4000 to -79.4010)
        let inactiveGreen = lineFeature(
            id: "green_1",
            street: "Queen St",
            side: "North",
            category: "no_parking",
            polarity: .inactive,
            coords: [[-79.4000, 43.6500], [-79.4010, 43.6500]]
        )
        // Red segment in the middle (from -79.4003 to -79.4007)
        let activeRed = lineFeature(
            id: "red_1",
            street: "Queen St",
            side: "North",
            category: "no_stopping",
            polarity: .restricted,
            coords: [[-79.4003, 43.6500], [-79.4007, 43.6500]]
        )

        let items = CurbOverlapResolver.resolveViewportOverlaps(features: [inactiveGreen, activeRed])

        let redItems = items.filter { $0.id.featureID.rawValue == "red_1" }
        let greenItems = items.filter { $0.id.featureID.rawValue == "green_1" }

        #expect(redItems.count == 1)
        #expect(greenItems.count == 2)
        #expect(redItems[0].severity == 2)
        #expect(greenItems.allSatisfy { $0.severity == 0 })

        #expect(redItems[0].coordinates.first?.longitude ?? 0 ≈ -79.4003)
        #expect(redItems[0].coordinates.last?.longitude ?? 0 ≈ -79.4007)

        #expect(greenItems[0].coordinates.first?.longitude ?? 0 ≈ -79.4000)
        #expect(greenItems[0].coordinates.last?.longitude ?? 0 ≈ -79.4003)

        #expect(greenItems[1].coordinates.first?.longitude ?? 0 ≈ -79.4007)
        #expect(greenItems[1].coordinates.last?.longitude ?? 0 ≈ -79.4010)
    }

    @Test("Tippett Rd scenario: Active No Standing (Red) overrides Permitted Window (Green) and slices it")
    func noStandingOverPermittedWindowSlicesPermittedWindow() {
        // 2-hour permitted window along the whole block
        let permitGreen = lineFeature(
            id: "permit_29132",
            street: "Tippett Rd",
            side: "East",
            category: "restricted_periods",
            polarity: .permitted,
            coords: [[-79.4000, 43.6500], [-79.4010, 43.6500]]
        )
        // No Standing Anytime in the middle
        let noStandingRed = lineFeature(
            id: "standing_30344",
            street: "Tippett Rd",
            side: "East",
            category: "no_standing",
            polarity: .restricted,
            coords: [[-79.4003, 43.6500], [-79.4007, 43.6500]]
        )

        let items = CurbOverlapResolver.resolveViewportOverlaps(features: [permitGreen, noStandingRed])

        let redItems = items.filter { $0.id.featureID.rawValue == "standing_30344" }
        let greenItems = items.filter { $0.id.featureID.rawValue == "permit_29132" }

        // No standing renders full (red), permitted window sliced into 2 green pieces
        #expect(redItems.count == 1)
        #expect(greenItems.count == 2)
        #expect(redItems[0].severity == 2)
        #expect(greenItems.allSatisfy { $0.severity == 0 })
    }

    @Test("Active permitted window green over active No Parking: permitted window wins and No Parking is sliced")
    func permittedWindowGreenOverActiveNoParkingSlicesNoParking() {
        // Red No Parking along the whole block
        let activeNoParking = lineFeature(
            id: "no_parking_full",
            street: "King St",
            side: "South",
            category: "no_parking",
            polarity: .restricted,
            coords: [[-79.4000, 43.6500], [-79.4010, 43.6500]]
        )
        // Permitted window in the middle
        let permitGreen = lineFeature(
            id: "permit_win",
            street: "King St",
            side: "South",
            category: "restricted_periods",
            polarity: .permitted,
            coords: [[-79.4003, 43.6500], [-79.4007, 43.6500]]
        )

        let items = CurbOverlapResolver.resolveViewportOverlaps(features: [activeNoParking, permitGreen])

        let greenItems = items.filter { $0.id.featureID.rawValue == "permit_win" }
        let redItems = items.filter { $0.id.featureID.rawValue == "no_parking_full" }

        #expect(greenItems.count == 1)
        #expect(redItems.count == 2)
        #expect(greenItems[0].severity == 0)
        #expect(redItems.allSatisfy { $0.severity == 2 })
    }

    @Test("Complete overlap of lower priority by higher priority removes lower priority feature")
    func completeOverlapRemovesLowerPriority() {
        let inactiveGreen = lineFeature(
            id: "green_sub",
            street: "Dundas St",
            side: "East",
            category: "no_parking",
            polarity: .inactive,
            coords: [[-79.4002, 43.6500], [-79.4006, 43.6500]]
        )
        let activeRed = lineFeature(
            id: "red_large",
            street: "Dundas St",
            side: "East",
            category: "no_stopping",
            polarity: .restricted,
            coords: [[-79.4000, 43.6500], [-79.4010, 43.6500]]
        )

        let items = CurbOverlapResolver.resolveViewportOverlaps(features: [inactiveGreen, activeRed])

        let redItems = items.filter { $0.id.featureID.rawValue == "red_large" }
        let greenItems = items.filter { $0.id.featureID.rawValue == "green_sub" }

        #expect(redItems.count == 1)
        #expect(greenItems.isEmpty)
    }

    @Test("Disjoint segments on the same street side remain intact without slicing")
    func disjointSegmentsRemainIntact() {
        let segA = lineFeature(
            id: "seg_a",
            street: "College St",
            side: "West",
            category: "no_parking",
            polarity: .inactive,
            coords: [[-79.4000, 43.6500], [-79.4004, 43.6500]]
        )
        let segB = lineFeature(
            id: "seg_b",
            street: "College St",
            side: "West",
            category: "no_stopping",
            polarity: .restricted,
            coords: [[-79.4010, 43.6500], [-79.4014, 43.6500]]
        )

        let items = CurbOverlapResolver.resolveViewportOverlaps(features: [segA, segB])

        #expect(items.count == 2)
        #expect(items.contains { $0.id.featureID.rawValue == "seg_a" })
        #expect(items.contains { $0.id.featureID.rawValue == "seg_b" })
    }

    @Test("Tapping on overlap evaluates both overlapping rules in verdict")
    func tappingOnOverlapEvaluatesBothRules() {
        let longInactive = lineFeature(
            id: "long_green",
            street: "Bay St",
            side: "East",
            category: "no_parking",
            polarity: .inactive,
            coords: [[-79.4000, 43.6500], [-79.4010, 43.6500]],
            schedule: Schedule(
                status: .ok,
                source: "8am-9am",
                windows: [TimeWindow(days: [1], startMinute: 480, endMinute: 540)]
            )
        )
        let shortRestricted = lineFeature(
            id: "short_red",
            street: "Bay St",
            side: "East",
            category: "no_stopping",
            polarity: .restricted,
            coords: [[-79.4003, 43.6500], [-79.4007, 43.6500]],
            schedule: Schedule(status: .anytime, source: "anytime")
        )

        // Tap in the middle of short_red at -79.4005
        let tap = LngLat(lng: -79.4005, lat: 43.65001)
        let result = CurbSelection.selectNearestCurb(
            features: [longInactive, shortRestricted],
            point: tap
        )

        #expect(result.selected != nil)
        let verdictFeatures = result.selected!.verdictFeatures
        #expect(verdictFeatures.count == 2)
        #expect(verdictFeatures.contains { $0.id.rawValue == "long_green" })
        #expect(verdictFeatures.contains { $0.id.rawValue == "short_red" })

        // Compose verdict for a standard slot
        let slot = Slot(dayOfWeek: 1, minuteOfDay: 600, month: 6, dayOfMonth: 15)
        let verdict = CurbVerdictComposer.composeCurbVerdict(
            features: verdictFeatures,
            slot: slot,
            effectiveEndMinute: 660,
            requestedDurationMinutes: 60
        )

        // Because of short_red (no_stopping), verdict status must be notAllowed
        #expect(verdict.status == .notAllowed)
        #expect(verdict.primaryReason == "No stopping")
    }
}

infix operator ≈: ComparisonPrecedence

private extension Double {
    static func ≈ (lhs: Double, rhs: Double) -> Bool {
        abs(lhs - rhs) < 0.00015
    }
}
