import Foundation

enum ScheduleCalendarLogic {
    nonisolated private static func monthDayValue(month: Int, day: Int) -> Int {
        month * 32 + day
    }

    nonisolated private static func inMonthRange(
        slot: Slot,
        range: CalendarMonthRange
    ) -> Bool {
        let slotMd = monthDayValue(month: slot.month, day: slot.dayOfMonth)
        let startMd = monthDayValue(month: range.startMonth, day: range.startDay)
        let endMd = monthDayValue(month: range.endMonth, day: range.endDay)
        if startMd <= endMd {
            return slotMd >= startMd && slotMd <= endMd
        }
        return slotMd >= startMd || slotMd <= endMd
    }

    nonisolated private static func lastDayOfMonth(year: Int, month: Int) -> Int {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.year = year
        components.month = month + 1
        components.day = 0
        let date = components.date ?? Date()
        return Calendar(identifier: .gregorian).component(.day, from: date)
    }

    nonisolated private static func resolveYear(_ slot: Slot) -> Int {
        slot.year ?? Calendar(identifier: .gregorian).component(.year, from: Date())
    }

    nonisolated private static func inDayOfMonthRange(
        slot: Slot,
        range: CalendarDayOfMonthRange
    ) -> Bool {
        let end: Int
        switch range.end {
        case .day(let value):
            end = value
        case .last:
            end = lastDayOfMonth(year: resolveYear(slot), month: slot.month)
        }
        return slot.dayOfMonth >= range.start && slot.dayOfMonth <= end
    }

    /// True when calendar is absent/empty or every present predicate passes.
    nonisolated static func slotInCalendar(
        _ calendar: ScheduleCalendar?,
        slot: Slot
    ) -> Bool {
        guard let calendar else { return true }

        let monthRanges = calendar.monthRanges ?? []
        let dayRanges = calendar.dayOfMonthRanges ?? []
        let months = calendar.months ?? []

        let hasMonthRanges = !monthRanges.isEmpty
        let hasDayRanges = !dayRanges.isEmpty
        let hasMonths = !months.isEmpty

        if !hasMonthRanges && !hasDayRanges && !hasMonths {
            return true
        }

        if hasMonthRanges && !monthRanges.contains(where: { inMonthRange(slot: slot, range: $0) }) {
            return false
        }

        if hasDayRanges && !dayRanges.contains(where: { inDayOfMonthRange(slot: slot, range: $0) }) {
            return false
        }

        if hasMonths && !months.contains(slot.month) {
            return false
        }

        return true
    }
}
