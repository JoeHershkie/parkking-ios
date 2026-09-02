import Foundation
import Testing
@testable import Parkking

@MainActor
@Suite("ParkingTimeQuery")
struct ParkingTimeQueryTests {
    private let toronto = TimeZone(identifier: "America/Toronto")!

    @Test("now + 60 resolves to Now · 1h chip")
    func nowPlusSixty() {
        // 2025-05-20 15:00 America/Toronto
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = toronto
        let now = cal.date(
            from: DateComponents(year: 2025, month: 5, day: 20, hour: 15, minute: 0)
        )!

        let query = ParkingTimeQuery.createNowTimeQuery(
            durationMinutes: 60,
            preset: .minutes(60),
            now: now,
            timeZone: toronto
        )
        let resolved = ParkingTimeQuery.resolveTimeQuery(query, now: now, timeZone: toronto)

        #expect(query.mode == .now)
        #expect(resolved.slot.minuteOfDay == 15 * 60)
        #expect(resolved.effectiveEndMinute == 16 * 60)
        #expect(resolved.truncatedAtMidnight == false)
        #expect(resolved.requestedDurationMinutes == 60)
        #expect(ParkingTimeQuery.formatTimeQueryChip(query: query, resolved: resolved) == "Now · 1h")
        #expect(ParkingTimeQuery.formatDurationLabel(60) == "1h")
    }

    @Test("resolves overnight query crossing midnight into next day")
    func resolvesOvernightQuery() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = toronto
        let now = cal.date(
            from: DateComponents(year: 2025, month: 5, day: 20, hour: 23, minute: 0)
        )!

        let query = ParkingTimeQuery.createNowTimeQuery(
            durationMinutes: 180,
            preset: .minutes(180),
            now: now,
            timeZone: toronto
        )
        let resolved = ParkingTimeQuery.resolveTimeQuery(query, now: now, timeZone: toronto)

        #expect(resolved.slot.minuteOfDay == 23 * 60)
        #expect(resolved.crossesMidnight == true)
        #expect(resolved.nextDaySlot?.dayOfWeek == 3) // Tuesday (2) -> Wednesday (3)
        #expect(resolved.nextDaySlot?.dayOfMonth == 21)
        #expect(resolved.nextDayEndMinute == 120) // 2:00am
        #expect(resolved.label == "11:00pm - 2:00am")
        #expect(ParkingTimeQuery.formatTimeQueryChip(query: query, resolved: resolved) == "Now · 3h")
    }

    @Test("overnight query starting at 23:59")
    func overnightStartingAtLateMinute() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = toronto
        let now = cal.date(
            from: DateComponents(year: 2025, month: 5, day: 20, hour: 12, minute: 0)
        )!
        let query = TimeQuery(
            mode: .custom,
            date: "2025-05-20",
            startMinute: 1439,
            requestedDurationMinutes: 60,
            durationPreset: .minutes(60)
        )
        let resolved = ParkingTimeQuery.resolveTimeQuery(query, now: now, timeZone: toronto)
        #expect(resolved.crossesMidnight == true)
        #expect(resolved.nextDaySlot?.dayOfMonth == 21)
        #expect(resolved.nextDayEndMinute == 59)
        #expect(resolved.label == "11:59pm - 12:59am")
    }

    @Test("clamps duration, recognizes presets, and previews midnight")
    func presetsClampingAndMidnightPreview() {
        #expect(ParkingTimeQuery.durationPresets == [30, 60, 120, 180])
        #expect(ParkingTimeQuery.clampDuration(0) == 1)
        #expect(ParkingTimeQuery.clampDuration(800) == 720)
        #expect(ParkingTimeQuery.clampDuration(90) == 90)
        #expect(ParkingTimeQuery.preset(for: 30) == .minutes(30))
        #expect(ParkingTimeQuery.preset(for: 60) == .minutes(60))
        #expect(ParkingTimeQuery.preset(for: 120) == .minutes(120))
        #expect(ParkingTimeQuery.preset(for: 180) == .minutes(180))
        #expect(ParkingTimeQuery.preset(for: 90) == .custom)
        #expect(ParkingTimeQuery.formatDurationLabel(30) == "30m")
        #expect(ParkingTimeQuery.formatDurationLabel(120) == "2h")
        #expect(ParkingTimeQuery.formatDurationLabel(180) == "3h")

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = toronto
        let evening = cal.date(
            from: DateComponents(year: 2025, month: 5, day: 20, hour: 23, minute: 0)
        )!
        let nowQuery = ParkingTimeQuery.createNowTimeQuery(
            durationMinutes: 120,
            preset: .minutes(120),
            now: evening,
            timeZone: toronto
        )
        #expect(ParkingTimeQuery.draftCrossesMidnight(nowQuery, now: evening, timeZone: toronto))

        let custom = TimeQuery(
            mode: .custom,
            date: "2025-05-20",
            startMinute: 10 * 60,
            requestedDurationMinutes: 30,
            durationPreset: .minutes(30)
        )
        #expect(ParkingTimeQuery.draftCrossesMidnight(custom, timeZone: toronto) == false)

        let date = ParkingTimeQuery.date(
            fromTorontoDateString: "2025-05-20",
            minuteOfDay: 15 * 60 + 30,
            timeZone: toronto
        )
        #expect(ParkingTimeQuery.torontoDateString(from: date, timeZone: toronto) == "2025-05-20")
        #expect(ParkingTimeQuery.minuteOfDay(from: date, timeZone: toronto) == 15 * 60 + 30)
    }

    @Test("formatSlotLabel formatting variants")
    func slotLabelFormattingVariants() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = toronto
        // Monday, August 31, 2026 at 17:28 (5:28pm)
        let now = cal.date(
            from: DateComponents(year: 2026, month: 8, day: 31, hour: 17, minute: 28)
        )!

        // Today (5:28pm - 6:28pm - no 'Today from')
        let todaySlot = Slot(dayOfWeek: 1, minuteOfDay: 17 * 60 + 28, month: 8, dayOfMonth: 31, year: 2026)
        let todayLabel = ParkingTimeQuery.formatSlotLabel(
            todaySlot,
            endMinuteOfDay: 18 * 60 + 28,
            now: now,
            timeZone: toronto
        )
        #expect(todayLabel == "5:28pm - 6:28pm")

        // Tomorrow (Tue Sep 1, 2026 - within 7 days)
        let tomorrowSlot = Slot(dayOfWeek: 2, minuteOfDay: 17 * 60 + 28, month: 9, dayOfMonth: 1, year: 2026)
        let tomorrowLabel = ParkingTimeQuery.formatSlotLabel(
            tomorrowSlot,
            endMinuteOfDay: 18 * 60 + 28,
            now: now,
            timeZone: toronto
        )
        #expect(tomorrowLabel == "Tue, 5:28pm - 6:28pm")

        // 6 days ahead (Sun Sep 6, 2026 - within 7 days)
        let sunSlot = Slot(dayOfWeek: 0, minuteOfDay: 17 * 60 + 28, month: 9, dayOfMonth: 6, year: 2026)
        let sunLabel = ParkingTimeQuery.formatSlotLabel(
            sunSlot,
            endMinuteOfDay: 18 * 60 + 28,
            now: now,
            timeZone: toronto
        )
        #expect(sunLabel == "Sun, 5:28pm - 6:28pm")

        // Later in current year (Mon Sep 14, 2026 - not within 7 days)
        let laterSlot = Slot(dayOfWeek: 1, minuteOfDay: 17 * 60 + 28, month: 9, dayOfMonth: 14, year: 2026)
        let laterLabel = ParkingTimeQuery.formatSlotLabel(
            laterSlot,
            endMinuteOfDay: 18 * 60 + 28,
            now: now,
            timeZone: toronto
        )
        #expect(laterLabel == "Mon 09-14, 5:28pm - 6:28pm")

        // Next year (Tue Aug 31, 2027)
        let nextYearSlot = Slot(dayOfWeek: 2, minuteOfDay: 17 * 60 + 28, month: 8, dayOfMonth: 31, year: 2027)
        let nextYearLabel = ParkingTimeQuery.formatSlotLabel(
            nextYearSlot,
            endMinuteOfDay: 18 * 60 + 28,
            now: now,
            timeZone: toronto
        )
        #expect(nextYearLabel == "Tue 2027-08-31, 5:28pm - 6:28pm")

        // Point check (no end time)
        let pointLabel = ParkingTimeQuery.formatSlotLabel(
            todaySlot,
            endMinuteOfDay: nil,
            now: now,
            timeZone: toronto
        )
        #expect(pointLabel == "5:28pm")
    }
}
