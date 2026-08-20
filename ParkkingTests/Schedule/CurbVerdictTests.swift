import Foundation
import Testing
@testable import Parkking

@Suite("Curb verdict")
struct CurbVerdictTests {
    private let tue3pm = Slot(
        dayOfWeek: 2,
        minuteOfDay: 900,
        month: 5,
        dayOfMonth: 20,
        year: 2025
    )

    private let monFri86 = Schedule(
        status: .ok,
        source: "Mon–Fri 8am–6pm",
        windows: [
            TimeWindow(days: [1, 2, 3, 4, 5], startMinute: 480, endMinute: 1080),
        ]
    )

    private func feature(
        _ category: String,
        _ schedule: Schedule?,
        extras: (inout ParkingProperties) -> Void = { _ in }
    ) -> ParkingFeature {
        var props = ParkingProperties(
            highway: "Test St",
            rule: "test rule",
            scheduleCategory: category,
            side: "North",
            max: nil,
            schedule: schedule,
            maxMinutes: nil
        )
        extras(&props)
        return ParkingFeature(
            id: FeatureID(0),
            geometry: .lineString(coordinates: [[-79.4, 43.65], [-79.401, 43.651]]),
            properties: props
        )
    }

    private func verdict(
        features: [ParkingFeature],
        slot: Slot,
        effectiveEndMinute: Int?,
        requestedDurationMinutes: Int,
        truncatedAtMidnight: Bool = false
    ) -> CurbVerdict {
        CurbVerdictComposer.composeCurbVerdict(
            ComposeCurbVerdictOptions(
                features: features,
                slot: slot,
                effectiveEndMinute: effectiveEndMinute,
                requestedDurationMinutes: requestedDurationMinutes,
                truncatedAtMidnight: truncatedAtMidnight
            )
        )
    }

    @Test func likelyAllowedWhenNoFeatures() {
        let v = verdict(
            features: [],
            slot: tue3pm,
            effectiveEndMinute: nil,
            requestedDurationMinutes: 60
        )
        #expect(v.status == .likelyAllowed)
        #expect(v.signageReminder == "Check posted signs.")
        #expect(v.primaryReason?.localizedCaseInsensitiveContains("incomplete") == true)
    }

    @Test func activeNoParkingNotAllowed() {
        let v = verdict(
            features: [feature("no_parking", monFri86)],
            slot: tue3pm,
            effectiveEndMinute: 960,
            requestedDurationMinutes: 60
        )
        #expect(v.status == .notAllowed)
        #expect(v.activeRestrictions.first?.kind == .noParking)
    }

    @Test func prefersNoStoppingOverNoParking() {
        let v = verdict(
            features: [
                feature("no_parking", monFri86),
                feature("no_stopping", monFri86),
            ],
            slot: tue3pm,
            effectiveEndMinute: nil,
            requestedDurationMinutes: 60
        )
        #expect(v.status == .notAllowed)
        #expect(v.primaryReason?.localizedCaseInsensitiveContains("stopping") == true)
    }

    @Test func maxStayWarning() {
        let v = verdict(
            features: [
                feature("restricted_periods", monFri86) {
                    $0.max = "1 hour"
                    $0.maxMinutes = 60
                },
            ],
            slot: tue3pm,
            effectiveEndMinute: 1020,
            requestedDurationMinutes: 120
        )
        #expect(v.status == .notAllowed)
        #expect(v.maxStayWarning?.localizedCaseInsensitiveContains("1 hour") == true)
    }

    @Test func failedScheduleUnclear() {
        let failed = Schedule(status: .failed, source: "bad", windows: [])
        let v = verdict(
            features: [feature("no_parking", failed)],
            slot: tue3pm,
            effectiveEndMinute: nil,
            requestedDurationMinutes: 60
        )
        #expect(v.status == .scheduleUnclear)
    }

    @Test func midnightWarning() {
        let v = verdict(
            features: [],
            slot: tue3pm,
            effectiveEndMinute: 1439,
            requestedDurationMinutes: 180,
            truncatedAtMidnight: true
        )
        #expect(v.midnightWarning?.localizedCaseInsensitiveContains("midnight") == true)
    }

    @Test func inactiveWeekendAllowed() {
        let sat = Slot(
            dayOfWeek: 6,
            minuteOfDay: 900,
            month: 5,
            dayOfMonth: 24,
            year: 2025
        )
        let v = verdict(
            features: [feature("no_parking", monFri86)],
            slot: sat,
            effectiveEndMinute: nil,
            requestedDurationMinutes: 60
        )
        #expect(v.status == .parkingAllowed)
    }

    @Test func complementaryPermittedWindows() {
        let daytime = Schedule(
            status: .ok,
            source: "Mon–Fri 8am–6pm",
            windows: [TimeWindow(days: [1, 2, 3, 4, 5], startMinute: 480, endMinute: 1080)]
        )
        let school = Schedule(
            status: .ok,
            source: "Mon–Fri 8–9 and 14:30–15:30",
            windows: [
                TimeWindow(days: [1, 2, 3, 4, 5], startMinute: 480, endMinute: 540),
                TimeWindow(days: [1, 2, 3, 4, 5], startMinute: 870, endMinute: 930),
            ]
        )
        let slot = Slot(
            dayOfWeek: 1,
            minuteOfDay: 17 * 60 + 35,
            month: 8,
            dayOfMonth: 10,
            year: 2026
        )
        let v = verdict(
            features: [
                feature("restricted_periods", daytime) {
                    $0.max = "1 hour"
                    $0.maxMinutes = 60
                },
                feature("restricted_periods", school) {
                    $0.max = "10 mins."
                    $0.maxMinutes = 10
                },
            ],
            slot: slot,
            effectiveEndMinute: 17 * 60 + 45,
            requestedDurationMinutes: 10
        )
        #expect(v.status == .parkingAllowed)
        #expect(v.primaryReason?.localizedCaseInsensitiveContains("outside the permitted") != true)
    }

    @Test func stillBansWhenEveryPermittedWindowExcludesInterval() {
        let school = Schedule(
            status: .ok,
            source: "Mon–Fri 8–9",
            windows: [
                TimeWindow(days: [1, 2, 3, 4, 5], startMinute: 480, endMinute: 540),
            ]
        )
        let v = verdict(
            features: [feature("restricted_periods", school)],
            slot: tue3pm,
            effectiveEndMinute: nil,
            requestedDurationMinutes: 30
        )
        #expect(v.status == .notAllowed)
        #expect(v.primaryReason?.localizedCaseInsensitiveContains("outside the permitted") == true)
    }
}
