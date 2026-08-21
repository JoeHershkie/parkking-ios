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

    @Test("truncates at midnight minute 1439")
    func midnightTruncation() {
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
        #expect(resolved.truncatedAtMidnight == true)
        #expect(resolved.effectiveEndMinute == ParkingTimeQuery.midnightMinute)
        #expect(ParkingTimeQuery.midnightMinute == 1439)
        #expect(
            ParkingTimeQuery.midnightWarning
                == "Checked through midnight only; later rules were not evaluated."
        )
    }

    @Test("point check when already at 23:59")
    func pointCheckAtMidnightMinute() {
        let query = TimeQuery(
            mode: .custom,
            date: "2025-05-20",
            startMinute: 1439,
            requestedDurationMinutes: 60,
            durationPreset: .minutes(60)
        )
        let resolved = ParkingTimeQuery.resolveTimeQuery(query, timeZone: toronto)
        #expect(resolved.effectiveEndMinute == nil)
        #expect(resolved.truncatedAtMidnight == true)
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
}
