import Foundation

/// Ontario statutory public holidays matching `date-holidays` CA/ON `type === "public"`.
/// No third-party dependency — dates computed locally.
enum OntarioPublicHolidays {
    struct MonthDay: Hashable, Sendable {
        var month: Int
        var day: Int

        nonisolated init(month: Int, day: Int) {
            self.month = month
            self.day = day
        }
    }

    /// Returns whether *slot* falls on an Ontario public holiday.
    /// Requires `year` on the slot (parity with web `isPublicHoliday`).
    nonisolated static func isPublicHoliday(_ slot: Slot) -> Bool {
        guard let year = slot.year else { return false }
        return publicHolidayDates(for: year).contains {
            $0.month == slot.month && $0.day == slot.dayOfMonth
        }
    }

    /// Public holiday calendar dates for a year (date-holidays CA/ON public set).
    nonisolated static func publicHolidayDates(for year: Int) -> Set<MonthDay> {
        var dates: Set<MonthDay> = []

        // New Year's Day — Jan 1 (no substitute in date-holidays CA)
        dates.insert(MonthDay(month: 1, day: 1))

        // Family Day — 3rd Monday in February
        dates.insert(nthWeekday(year: year, month: 2, weekday: 2, n: 3))

        let easterSunday = easterSunday(year: year)
        // Good Friday
        dates.insert(shift(easterSunday, by: -2))
        // Easter Sunday
        dates.insert(easterSunday)
        // Easter Monday (ON)
        dates.insert(shift(easterSunday, by: 1))

        // Victoria Day — Monday before May 25
        dates.insert(victoriaDay(year: year))

        // Canada Day — July 1 (no substitute in date-holidays CA)
        dates.insert(MonthDay(month: 7, day: 1))

        // Civic Holiday — 1st Monday in August
        dates.insert(nthWeekday(year: year, month: 8, weekday: 2, n: 1))

        // Labour Day — 1st Monday in September
        dates.insert(nthWeekday(year: year, month: 9, weekday: 2, n: 1))

        // Thanksgiving — 2nd Monday in October
        dates.insert(nthWeekday(year: year, month: 10, weekday: 2, n: 2))

        // Remembrance Day — Nov 11
        dates.insert(MonthDay(month: 11, day: 11))

        // Christmas Day — Dec 25
        dates.insert(MonthDay(month: 12, day: 25))

        // Boxing Day — Dec 26
        dates.insert(MonthDay(month: 12, day: 26))

        return dates
    }

    // MARK: - Helpers

    /// Foundation weekday: 1=Sunday … 7=Saturday.
    nonisolated private static func nthWeekday(
        year: Int,
        month: Int,
        weekday: Int,
        n: Int
    ) -> MonthDay {
        let cal = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let first = cal.date(from: components) else {
            return MonthDay(month: month, day: 1)
        }
        let firstWeekday = cal.component(.weekday, from: first)
        var day = 1 + (weekday - firstWeekday + 7) % 7
        day += (n - 1) * 7
        return MonthDay(month: month, day: day)
    }

    nonisolated private static func victoriaDay(year: Int) -> MonthDay {
        // Monday before May 25 ≡ Monday on or before May 24
        let cal = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = year
        components.month = 5
        components.day = 24
        guard let may24 = cal.date(from: components) else {
            return MonthDay(month: 5, day: 24)
        }
        let weekday = cal.component(.weekday, from: may24)
        let daysSinceMonday = (weekday + 5) % 7
        return shift(MonthDay(month: 5, day: 24), by: -daysSinceMonday)
    }

    /// Anonymous Gregorian algorithm for Easter Sunday.
    nonisolated private static func easterSunday(year: Int) -> MonthDay {
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = ((h + l - 7 * m + 114) % 31) + 1
        return MonthDay(month: month, day: day)
    }

    nonisolated private static func shift(_ md: MonthDay, by: Int) -> MonthDay {
        let cal = Calendar(identifier: .gregorian)
        var components = DateComponents()
        // Year is not on MonthDay; shift within a synthetic year 2000 (non-leap issues
        // only matter across Feb 29 — Easter/Christmas shifts stay in Mar–Apr / Dec–Jan).
        // For Dec→Jan and Good Friday we need a real year context when calling from
        // publicHolidayDates — use a leap-safe approach with an explicit year.
        // Callers always pass dates that stay in-year for Easter; Christmas± never crosses
        // year for Boxing Day offsets of 0. Use year 2001 as a non-leap placeholder only
        // when month is not near year boundaries... Better: require year.
        components.year = 2000
        components.month = md.month
        components.day = md.day
        guard let date = cal.date(from: components),
              let shifted = cal.date(byAdding: .day, value: by, to: date)
        else {
            return md
        }
        return MonthDay(
            month: cal.component(.month, from: shifted),
            day: cal.component(.day, from: shifted)
        )
    }
}
