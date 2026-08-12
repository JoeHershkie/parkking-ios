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
}
