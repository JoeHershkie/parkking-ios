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
        crossesMidnight: Bool = false,
        nextDaySlot: Slot? = nil,
        nextDayEndMinute: Int? = nil,
        truncatedAtMidnight: Bool = false
    ) -> CurbVerdict {
        CurbVerdictComposer.composeCurbVerdict(
            ComposeCurbVerdictOptions(
                features: features,
                slot: slot,
                effectiveEndMinute: effectiveEndMinute,
                requestedDurationMinutes: requestedDurationMinutes,
                crossesMidnight: crossesMidnight,
                nextDaySlot: nextDaySlot,
                nextDayEndMinute: nextDayEndMinute,
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
        #expect(v.primaryReason == "No stopping")
        #expect(v.activeRestrictions.count == 2)
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
        #expect(v.status == .partiallyAllowed)
        #expect(v.headline == "Partially allowed, from 3:00pm to 4:00pm")
        #expect(v.allowedStartMinute == 900)
        #expect(v.allowedEndMinute == 960)
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

    @Test func allowedPeriodDurationFormatting() {
        #expect(ParkingLabels.scheduleCategoryLabel("restricted_periods") == "Allowed periods")
        #expect(ParkingLabels.formatAllowedPeriodDuration(max: "1 hour", maxMinutes: 60) == "1 hr")
        #expect(ParkingLabels.formatAllowedPeriodDuration(max: "10 mins.", maxMinutes: 10) == "10 min")
        #expect(ParkingLabels.formatAllowedPeriodDuration(max: "2 hours", maxMinutes: 120) == "2 hr")
        #expect(ParkingLabels.formatAllowedPeriodDuration(max: "15 min", maxMinutes: 15) == "15 min")
        #expect(ParkingLabels.formatAllowedPeriodDuration(max: "anytime", maxMinutes: nil) == "anytime")
    }

    @Test func partiallyAllowedWhenRestrictionEndsDuringInterval() {
        let tue5pm = Slot(
            dayOfWeek: 2,
            minuteOfDay: 17 * 60, // 5:00pm = 1020
            month: 5,
            dayOfMonth: 20,
            year: 2025
        )
        let v = verdict(
            features: [feature("no_parking", monFri86)],
            slot: tue5pm,
            effectiveEndMinute: 19 * 60, // 7:00pm = 1140
            requestedDurationMinutes: 120
        )
        #expect(v.status == .partiallyAllowed)
        #expect(v.headline == "Partially allowed, from 6:00pm to 7:00pm")
        #expect(v.allowedStartMinute == 18 * 60)
        #expect(v.allowedEndMinute == 19 * 60)
        #expect(v.activeRestrictions.first?.kind == .noParking)
    }

    @Test func partiallyAllowedWhenRestrictionStartsDuringInterval() {
        let noStopping4to6 = Schedule(
            status: .ok,
            source: "Mon–Fri 4pm–6pm",
            windows: [
                TimeWindow(days: [1, 2, 3, 4, 5], startMinute: 16 * 60, endMinute: 18 * 60),
            ]
        )
        let v = verdict(
            features: [feature("no_stopping", noStopping4to6)],
            slot: tue3pm, // 3:00pm = 900
            effectiveEndMinute: 17 * 60, // 5:00pm = 1020
            requestedDurationMinutes: 120
        )
        #expect(v.status == .partiallyAllowed)
        #expect(v.headline == "Partially allowed, from 3:00pm to 4:00pm")
        #expect(v.allowedStartMinute == 15 * 60)
        #expect(v.allowedEndMinute == 16 * 60)
        #expect(v.activeRestrictions.first?.kind == .noStopping)
    }

    @Test func partiallyAllowedWhenPermittedWindowEndsDuringInterval() {
        let tue5pm = Slot(
            dayOfWeek: 2,
            minuteOfDay: 17 * 60, // 5:00pm = 1020
            month: 5,
            dayOfMonth: 20,
            year: 2025
        )
        let v = verdict(
            features: [feature("restricted_periods", monFri86)],
            slot: tue5pm,
            effectiveEndMinute: 19 * 60, // 7:00pm = 1140
            requestedDurationMinutes: 120
        )
        #expect(v.status == .partiallyAllowed)
        #expect(v.headline == "Partially allowed, from 5:00pm to 6:00pm")
        #expect(v.allowedStartMinute == 17 * 60)
        #expect(v.allowedEndMinute == 18 * 60)
    }

    @Test func permittedWindowOverridesGeneralNoParking() {
        let anytimeNoParking = Schedule(status: .anytime, source: "Anytime")
        let v = verdict(
            features: [
                feature("no_parking", anytimeNoParking),
                feature("restricted_periods", monFri86) {
                    $0.max = "1 hour"
                    $0.maxMinutes = 60
                },
            ],
            slot: tue3pm,
            effectiveEndMinute: 16 * 60,
            requestedDurationMinutes: 60
        )
        #expect(v.status == .parkingAllowed)
        #expect(v.headline == "Parking allowed")
    }

    @Test func noStandingOverridesPermittedWindow() {
        let anytimeNoStanding = Schedule(status: .anytime, source: "Anytime")
        let anytimePermit = Schedule(status: .anytime, source: "Anytime")
        let v = verdict(
            features: [
                feature("restricted_periods", anytimePermit) {
                    $0.max = "2 hours"
                    $0.maxMinutes = 120
                },
                feature("no_standing", anytimeNoStanding),
            ],
            slot: tue3pm,
            effectiveEndMinute: 16 * 60,
            requestedDurationMinutes: 60
        )
        #expect(v.status == .notAllowed)
        #expect(v.primaryReason == "No standing")
    }

    @Test func noStoppingOverridesPermittedWindow() {
        let anytimeNoStopping = Schedule(status: .anytime, source: "Anytime")
        let v = verdict(
            features: [
                feature("restricted_periods", monFri86) {
                    $0.max = "1 hour"
                    $0.maxMinutes = 60
                },
                feature("no_stopping", anytimeNoStopping),
            ],
            slot: tue3pm,
            effectiveEndMinute: 16 * 60,
            requestedDurationMinutes: 60
        )
        #expect(v.status == .notAllowed)
        #expect(v.primaryReason == "No stopping")
    }

    @Test func anytimePermitWithLongStayPartiallyAllowed() {
        let anytimePermit = Schedule(status: .anytime, source: "Anytime")
        let slot = Slot(
            dayOfWeek: 1,
            minuteOfDay: 19 * 60 + 39, // 7:39pm = 1179
            month: 8,
            dayOfMonth: 31,
            year: 2026
        )
        let feat = feature("restricted_periods", anytimePermit) {
            $0.max = "1 hour"
            $0.maxMinutes = 60
        }
        let v = verdict(
            features: [feat],
            slot: slot,
            effectiveEndMinute: 22 * 60 + 39, // 10:39pm = 1359
            requestedDurationMinutes: 180
        )
        #expect(v.status == .partiallyAllowed)
        #expect(v.headline == "Partially allowed, from 7:39pm to 8:39pm")
        #expect(v.allowedStartMinute == 19 * 60 + 39)
        #expect(v.allowedEndMinute == 20 * 60 + 39)
        #expect(v.maxStayWarning?.localizedCaseInsensitiveContains("1 hour") == true)

        let evaluation = ScheduleEvaluator.evaluateInRange(
            props: feat.properties,
            slot: slot,
            endMinuteOfDay: 22 * 60 + 39,
            includeUnknown: true
        )
        #expect(evaluation.polarity == .partial)
    }

    @Test func overnightNoParkingAcrossMidnight() {
        // Daily 11pm - 6am No Parking
        let overnightNoParking = Schedule(
            status: .ok,
            source: "11pm - 6am daily",
            windows: [
                TimeWindow(
                    days: [0, 1, 2, 3, 4, 5, 6],
                    startMinute: 23 * 60, // 1380
                    endMinute: 6 * 60,   // 360
                    crossesMidnight: true
                ),
            ]
        )
        let mondayNight = Slot(dayOfWeek: 1, minuteOfDay: 23 * 60, month: 5, dayOfMonth: 19, year: 2025)
        let tuesdaySlot = Slot(dayOfWeek: 2, minuteOfDay: 0, month: 5, dayOfMonth: 20, year: 2025)

        let v = verdict(
            features: [feature("no_parking", overnightNoParking)],
            slot: mondayNight,
            effectiveEndMinute: 1440,
            requestedDurationMinutes: 120, // 11pm Mon to 1am Tue
            crossesMidnight: true,
            nextDaySlot: tuesdaySlot,
            nextDayEndMinute: 60
        )
        #expect(v.status == .notAllowed)
        #expect(v.primaryReason == "No parking")
    }

    @Test func overnightPartialAllowanceAcrossMidnight() {
        // Monday-only 11pm - 12am No Parking
        let mondayNightOnly = Schedule(
            status: .ok,
            source: "Mon 11pm - 12am",
            windows: [
                TimeWindow(
                    days: [1],
                    startMinute: 23 * 60, // 1380
                    endMinute: 1440,
                    crossesMidnight: false
                ),
            ]
        )
        let mondayNight = Slot(dayOfWeek: 1, minuteOfDay: 23 * 60, month: 5, dayOfMonth: 19, year: 2025)
        let tuesdaySlot = Slot(dayOfWeek: 2, minuteOfDay: 0, month: 5, dayOfMonth: 20, year: 2025)

        let v = verdict(
            features: [feature("no_parking", mondayNightOnly)],
            slot: mondayNight,
            effectiveEndMinute: 1440,
            requestedDurationMinutes: 120, // 11pm Mon to 1am Tue
            crossesMidnight: true,
            nextDaySlot: tuesdaySlot,
            nextDayEndMinute: 60
        )
        #expect(v.status == .partiallyAllowed)
        #expect(v.headline == "Partially allowed, from 12:00am to 1:00am")
        #expect(v.allowedStartMinute == 0)
        #expect(v.allowedEndMinute == 60)
    }

    @Test func overnightPermittedWindow() {
        // Daily Permit Parking 12am - 7am
        let permitParking = Schedule(
            status: .ok,
            source: "12am - 7am daily",
            windows: [
                TimeWindow(
                    days: [0, 1, 2, 3, 4, 5, 6],
                    startMinute: 0,
                    endMinute: 7 * 60 // 420
                ),
            ]
        )
        let mondayNight = Slot(dayOfWeek: 1, minuteOfDay: 23 * 60, month: 5, dayOfMonth: 19, year: 2025)
        let tuesdaySlot = Slot(dayOfWeek: 2, minuteOfDay: 0, month: 5, dayOfMonth: 20, year: 2025)

        let v = verdict(
            features: [feature("restricted_periods", permitParking)],
            slot: mondayNight,
            effectiveEndMinute: 1440,
            requestedDurationMinutes: 180, // 11pm Mon to 2am Tue
            crossesMidnight: true,
            nextDaySlot: tuesdaySlot,
            nextDayEndMinute: 120
        )
        #expect(v.status == .partiallyAllowed)
        #expect(v.headline == "Partially allowed, from 12:00am to 2:00am")
        #expect(v.allowedStartMinute == 0)
        #expect(v.allowedEndMinute == 120)
    }

    @Test func inactiveWinterRuleSuppressedFromVisibilityAndGivesLikelyAllowed() {
        // Dec 1 - Mar 31 No Parking 2am-6am
        let winterSchedule = Schedule(
            status: .ok,
            source: "Dec 1 - Mar 31 2am-6am",
            windows: [
                TimeWindow(days: [0, 1, 2, 3, 4, 5, 6], startMinute: 120, endMinute: 360)
            ],
            calendar: ScheduleCalendar(
                monthRanges: [
                    CalendarMonthRange(startMonth: 12, startDay: 1, endMonth: 3, endDay: 31)
                ]
            )
        )
        let winterFeat = feature("no_parking", winterSchedule)
        let maySlot = Slot(dayOfWeek: 2, minuteOfDay: 180, month: 5, dayOfMonth: 15, year: 2026)

        let eval = ScheduleEvaluator.evaluateAtSlot(props: winterFeat.properties, slot: maySlot, includeUnknown: true)
        #expect(eval.visible == false)
        #expect(eval.polarity == FilterPolarity.inactive)

        let v = verdict(
            features: [winterFeat],
            slot: maySlot,
            effectiveEndMinute: nil,
            requestedDurationMinutes: 60
        )
        #expect(v.status == CurbVerdictStatus.likelyAllowed)
        #expect(v.headline == "Likely allowed")
        #expect(v.primaryReason == "No active restriction for this interval.")
    }

    @Test func activeWinterRuleShowsRestricted() {
        let winterSchedule = Schedule(
            status: .ok,
            source: "Dec 1 - Mar 31 2am-6am",
            windows: [
                TimeWindow(days: [0, 1, 2, 3, 4, 5, 6], startMinute: 120, endMinute: 360)
            ],
            calendar: ScheduleCalendar(
                monthRanges: [
                    CalendarMonthRange(startMonth: 12, startDay: 1, endMonth: 3, endDay: 31)
                ]
            )
        )
        let winterFeat = feature("no_parking", winterSchedule)
        let janSlot = Slot(dayOfWeek: 2, minuteOfDay: 180, month: 1, dayOfMonth: 15, year: 2026)

        let eval = ScheduleEvaluator.evaluateAtSlot(props: winterFeat.properties, slot: janSlot, includeUnknown: true)
        #expect(eval.visible == true)
        #expect(eval.polarity == FilterPolarity.restricted)

        let v = verdict(
            features: [winterFeat],
            slot: janSlot,
            effectiveEndMinute: nil,
            requestedDurationMinutes: 60
        )
        #expect(v.status == CurbVerdictStatus.notAllowed)
        #expect(v.headline == "Not allowed")
    }

    @Test func inactiveSnowStormSuppressedFromVisibility() {
        let snowStormSchedule = Schedule(
            status: .ok,
            source: "During major snow storm",
            condition: "major_snowstorm_declared"
        )
        let feat = feature("no_parking", snowStormSchedule)
        let calmSlot = Slot(dayOfWeek: 2, minuteOfDay: 600, month: 1, dayOfMonth: 15, year: 2026, majorSnowstorm: false)

        let eval = ScheduleEvaluator.evaluateAtSlot(props: feat.properties, slot: calmSlot, includeUnknown: true)
        #expect(eval.visible == false)
        #expect(eval.polarity == FilterPolarity.inactive)

        let v = verdict(
            features: [feat],
            slot: calmSlot,
            effectiveEndMinute: nil,
            requestedDurationMinutes: 60
        )
        #expect(v.status == CurbVerdictStatus.likelyAllowed)
        #expect(v.headline == "Likely allowed")
        #expect(v.primaryReason == "No active restriction for this interval.")
    }

    @Test func activeSnowStormDeclaredShowsRestricted() {
        let snowStormSchedule = Schedule(
            status: .ok,
            source: "During major snow storm",
            condition: "major_snowstorm_declared"
        )
        let feat = feature("no_parking", snowStormSchedule)
        let emergencySlot = Slot(dayOfWeek: 2, minuteOfDay: 600, month: 1, dayOfMonth: 15, year: 2026, majorSnowstorm: true)

        let eval = ScheduleEvaluator.evaluateAtSlot(props: feat.properties, slot: emergencySlot, includeUnknown: true)
        #expect(eval.visible == true)
        #expect(eval.polarity == FilterPolarity.restricted)

        let v = verdict(
            features: [feat],
            slot: emergencySlot,
            effectiveEndMinute: nil,
            requestedDurationMinutes: 60
        )
        #expect(v.status == CurbVerdictStatus.notAllowed)
        #expect(v.headline == "Not allowed")
    }

    @Test func winterMaintenanceCategorySuppressedFromVisibilityAndGivesLikelyAllowed() {
        // 2:00 a.m. to 6:00 a.m. from Dec. 1 to Mar. 31 under category winter_maintenance (like Cranbrooke Ave)
        let schedule = Schedule(
            status: .ok,
            source: "2:00 a.m. to 6:00 a.m. from Dec. 1 to Mar. 31",
            windows: [
                TimeWindow(
                    days: [0, 1, 2, 3, 4, 5, 6],
                    startMinute: 120,
                    endMinute: 360,
                    crossesMidnight: false,
                    calendar: ScheduleCalendar(
                        monthRanges: [CalendarMonthRange(startMonth: 12, startDay: 1, endMonth: 3, endDay: 31)]
                    )
                )
            ]
        )
        let feat = feature("winter_maintenance", schedule)

        // Slot in September (outside winter) at 3:16 AM
        let septSlot = Slot(dayOfWeek: 3, minuteOfDay: 196, month: 9, dayOfMonth: 2, year: 2026)
        let eval = ScheduleEvaluator.evaluateAtSlot(props: feat.properties, slot: septSlot, includeUnknown: true)
        #expect(eval.visible == false)
        #expect(eval.polarity == FilterPolarity.inactive)

        let v = verdict(
            features: [feat],
            slot: septSlot,
            effectiveEndMinute: nil,
            requestedDurationMinutes: 60
        )
        #expect(v.status == CurbVerdictStatus.likelyAllowed)
        #expect(v.headline == "Likely allowed")
        #expect(v.primaryReason == "No active restriction for this interval.")
    }

    @Test func daytimePermittedParkingWithRegionalWinterRuleMetadataRendersGreen() {
        // 8:00 a.m. to 6:00 p.m. restricted_periods with regionalWinterRule metadata
        let schedule = Schedule(
            status: .ok,
            source: "8:00 a.m. to 6:00 p.m.",
            windows: [
                TimeWindow(days: [0, 1, 2, 3, 4, 5, 6], startMinute: 480, endMinute: 1080)
            ]
        )
        let feat = feature("restricted_periods", schedule) {
            $0.highway = "Dunmurray Blvd"
            $0.rule = "8:00 a.m. to 6:00 p.m."
            $0.regionalWinterRule = "2:00 a.m. to 6:00 a.m. from Nov. 1 to Mar. 31"
        }

        // Query at 2:00 PM (840 min)
        let afternoonSlot = Slot(dayOfWeek: 3, minuteOfDay: 840, month: 9, dayOfMonth: 2, year: 2026)
        let eval = ScheduleEvaluator.evaluateAtSlot(props: feat.properties, slot: afternoonSlot, includeUnknown: true)
        #expect(eval.visible == true)
        #expect(eval.polarity == FilterPolarity.permitted)

        let v = verdict(
            features: [feat],
            slot: afternoonSlot,
            effectiveEndMinute: nil,
            requestedDurationMinutes: 60
        )
        #expect(v.status == CurbVerdictStatus.parkingAllowed)
        #expect(v.headline == "Parking allowed")
    }

    @Test func daytimeProhibitionOutsideActiveHoursWithRegionalWinterRuleMetadataRendersGreen() {
        // 8:00 a.m. to 6:00 p.m. Mon to Fri No Parking with regionalWinterRule metadata
        let schedule = Schedule(
            status: .ok,
            source: "8:00 a.m. to 6:00 p.m., Mon. to Fri.",
            windows: [
                TimeWindow(days: [1, 2, 3, 4, 5], startMinute: 480, endMinute: 1080)
            ]
        )
        let feat = feature("no_parking", schedule) {
            $0.highway = "Fairlawn Ave"
            $0.rule = "8:00 a.m. to 6:00 p.m., Mon. to Fri."
            $0.regionalWinterRule = "2:00 a.m. to 6:00 a.m. from Dec. 1 to Mar. 31"
        }

        // Query on Saturday at 2:00 PM (daytime prohibition not active)
        let saturdaySlot = Slot(dayOfWeek: 6, minuteOfDay: 840, month: 9, dayOfMonth: 5, year: 2026)
        let eval = ScheduleEvaluator.evaluateAtSlot(props: feat.properties, slot: saturdaySlot, includeUnknown: true)
        #expect(eval.visible == true)
        #expect(eval.polarity == FilterPolarity.inactive)

        let v = verdict(
            features: [feat],
            slot: saturdaySlot,
            effectiveEndMinute: nil,
            requestedDurationMinutes: 60
        )
        #expect(v.status == CurbVerdictStatus.parkingAllowed)
        #expect(v.headline == "Parking allowed")
    }
}
