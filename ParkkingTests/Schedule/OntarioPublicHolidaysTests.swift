import Foundation
import Testing
@testable import Parkking

@MainActor
@Suite("OntarioPublicHolidays")
struct OntarioPublicHolidaysTests {
    @Test("Canada Day 2025 is a public holiday")
    func canadaDay2025() {
        let slot = Slot(
            dayOfWeek: 2,
            minuteOfDay: 1020,
            month: 7,
            dayOfMonth: 1,
            year: 2025
        )
        #expect(OntarioPublicHolidays.isPublicHoliday(slot))
    }

    @Test("July 2 2025 is not a public holiday")
    func july2_2025() {
        let slot = Slot(
            dayOfWeek: 3,
            minuteOfDay: 1020,
            month: 7,
            dayOfMonth: 2,
            year: 2025
        )
        #expect(!OntarioPublicHolidays.isPublicHoliday(slot))
    }

    @Test("Christmas 2025 is a public holiday")
    func christmas2025() {
        let slot = Slot(
            dayOfWeek: 4,
            minuteOfDay: 0,
            month: 12,
            dayOfMonth: 25,
            year: 2025
        )
        #expect(OntarioPublicHolidays.isPublicHoliday(slot))
    }

    @Test("requires year")
    func requiresYear() {
        let slot = Slot(
            dayOfWeek: 4,
            minuteOfDay: 0,
            month: 12,
            dayOfMonth: 25,
            year: nil
        )
        #expect(!OntarioPublicHolidays.isPublicHoliday(slot))
    }

    @Test("Family Day Good Friday Victoria Day Labour Day 2025–2026")
    func namedHolidays2025_2026() {
        // Family Day 2025-02-17 (Mon)
        #expect(
            OntarioPublicHolidays.isPublicHoliday(
                Slot(dayOfWeek: 1, minuteOfDay: 0, month: 2, dayOfMonth: 17, year: 2025)
            )
        )
        // Good Friday 2025-04-18
        #expect(
            OntarioPublicHolidays.isPublicHoliday(
                Slot(dayOfWeek: 5, minuteOfDay: 0, month: 4, dayOfMonth: 18, year: 2025)
            )
        )
        // Victoria Day 2025-05-19
        #expect(
            OntarioPublicHolidays.isPublicHoliday(
                Slot(dayOfWeek: 1, minuteOfDay: 0, month: 5, dayOfMonth: 19, year: 2025)
            )
        )
        // Labour Day 2025-09-01
        #expect(
            OntarioPublicHolidays.isPublicHoliday(
                Slot(dayOfWeek: 1, minuteOfDay: 0, month: 9, dayOfMonth: 1, year: 2025)
            )
        )
        // Thanksgiving 2026-10-12
        #expect(
            OntarioPublicHolidays.isPublicHoliday(
                Slot(dayOfWeek: 1, minuteOfDay: 0, month: 10, dayOfMonth: 12, year: 2026)
            )
        )
        // Civic Holiday 2026-08-03
        #expect(
            OntarioPublicHolidays.isPublicHoliday(
                Slot(dayOfWeek: 1, minuteOfDay: 0, month: 8, dayOfMonth: 3, year: 2026)
            )
        )
        // Boxing Day 2025-12-26
        #expect(
            OntarioPublicHolidays.isPublicHoliday(
                Slot(dayOfWeek: 5, minuteOfDay: 0, month: 12, dayOfMonth: 26, year: 2025)
            )
        )
    }
}
