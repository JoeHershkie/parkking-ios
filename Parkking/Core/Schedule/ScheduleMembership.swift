import Foundation

enum ScheduleMembership {
    nonisolated static func minuteInWindow(
        minute: Int,
        start: Int,
        end: Int,
        crossesMidnight: Bool?
    ) -> Bool {
        if crossesMidnight == true || end <= start {
            return minute >= start || minute < end
        }
        return minute >= start && minute < end
    }

    /// Half-open [aStart, aEnd) overlaps [bStart, bEnd) on the same day (no wrap).
    nonisolated private static func halfOpenRangesOverlap(
        aStart: Int,
        aEnd: Int,
        bStart: Int,
        bEnd: Int
    ) -> Bool {
        aStart < bEnd && bStart < aEnd
    }

    nonisolated static func windowOverlapsQueryRange(
        qStart: Int,
        qEnd: Int,
        wStart: Int,
        wEnd: Int,
        crossesMidnight: Bool?
    ) -> Bool {
        if crossesMidnight == true || wEnd <= wStart {
            return halfOpenRangesOverlap(aStart: qStart, aEnd: qEnd, bStart: wStart, bEnd: 1440)
                || halfOpenRangesOverlap(aStart: qStart, aEnd: qEnd, bStart: 0, bEnd: wEnd)
        }
        return halfOpenRangesOverlap(aStart: qStart, aEnd: qEnd, bStart: wStart, bEnd: wEnd)
    }

    nonisolated private static func rangeFullyInsideWindow(
        qStart: Int,
        qEnd: Int,
        wStart: Int,
        wEnd: Int,
        crossesMidnight: Bool?
    ) -> Bool {
        if crossesMidnight == true || wEnd <= wStart {
            let inEvening =
                qStart >= wStart
                && qEnd <= 1440
                && halfOpenRangesOverlap(aStart: qStart, aEnd: qEnd, bStart: wStart, bEnd: 1440)
            let inMorning =
                qStart >= 0
                && qEnd <= wEnd
                && halfOpenRangesOverlap(aStart: qStart, aEnd: qEnd, bStart: 0, bEnd: wEnd)
            return inEvening || inMorning
        }
        return qStart >= wStart && qEnd <= wEnd
    }

    nonisolated private static func effectiveCalendar(
        window: TimeWindow,
        schedule: Schedule
    ) -> ScheduleCalendar? {
        window.calendar ?? schedule.calendar
    }

    nonisolated private static func holidayExcludesWindow(
        schedule: Schedule,
        slot: Slot
    ) -> Bool {
        schedule.flags?.exceptPublicHolidays == true
            && OntarioPublicHolidays.isPublicHoliday(slot)
    }

    nonisolated private static func windowMatchesSlot(
        window: TimeWindow,
        schedule: Schedule,
        slot: Slot
    ) -> Bool {
        guard ScheduleCalendarLogic.slotInCalendar(
            effectiveCalendar(window: window, schedule: schedule),
            slot: slot
        ) else { return false }
        guard window.days.contains(slot.dayOfWeek) else { return false }
        guard minuteInWindow(
            minute: slot.minuteOfDay,
            start: window.startMinute,
            end: window.endMinute,
            crossesMidnight: window.crossesMidnight
        ) else { return false }
        if holidayExcludesWindow(schedule: schedule, slot: slot) { return false }
        return true
    }

    nonisolated private static func exceptWindowMatchesSlot(
        window: TimeWindow,
        schedule: Schedule,
        slot: Slot
    ) -> Bool {
        if holidayExcludesWindow(schedule: schedule, slot: slot) { return true }
        guard ScheduleCalendarLogic.slotInCalendar(
            effectiveCalendar(window: window, schedule: schedule),
            slot: slot
        ) else { return false }
        guard window.days.contains(slot.dayOfWeek) else { return false }
        return minuteInWindow(
            minute: slot.minuteOfDay,
            start: window.startMinute,
            end: window.endMinute,
            crossesMidnight: window.crossesMidnight
        )
    }

    nonisolated private static func windowMatchesSlotInRange(
        window: TimeWindow,
        schedule: Schedule,
        slot: Slot,
        endMinute: Int
    ) -> Bool {
        guard ScheduleCalendarLogic.slotInCalendar(
            effectiveCalendar(window: window, schedule: schedule),
            slot: slot
        ) else { return false }
        guard window.days.contains(slot.dayOfWeek) else { return false }
        guard windowOverlapsQueryRange(
            qStart: slot.minuteOfDay,
            qEnd: endMinute,
            wStart: window.startMinute,
            wEnd: window.endMinute,
            crossesMidnight: window.crossesMidnight
        ) else { return false }
        if holidayExcludesWindow(schedule: schedule, slot: slot) { return false }
        return true
    }

    nonisolated private static func exceptWindowMatchesRange(
        window: TimeWindow,
        schedule: Schedule,
        slot: Slot,
        endMinute: Int
    ) -> Bool {
        if holidayExcludesWindow(schedule: schedule, slot: slot) { return true }
        guard ScheduleCalendarLogic.slotInCalendar(
            effectiveCalendar(window: window, schedule: schedule),
            slot: slot
        ) else { return false }
        guard window.days.contains(slot.dayOfWeek) else { return false }
        return windowOverlapsQueryRange(
            qStart: slot.minuteOfDay,
            qEnd: endMinute,
            wStart: window.startMinute,
            wEnd: window.endMinute,
            crossesMidnight: window.crossesMidnight
        )
    }

    nonisolated private static func matchesWithWindows(
        schedule: Schedule,
        slot: Slot,
        inverted: Bool
    ) -> Bool {
        let windows = schedule.windows
        if inverted {
            guard ScheduleCalendarLogic.slotInCalendar(schedule.calendar, slot: slot) else {
                return false
            }
            for w in windows {
                if exceptWindowMatchesSlot(window: w, schedule: schedule, slot: slot) {
                    return false
                }
            }
            return true
        }
        for w in windows {
            if windowMatchesSlot(window: w, schedule: schedule, slot: slot) {
                return true
            }
        }
        return false
    }

    nonisolated private static func matchesWithWindowsInRange(
        schedule: Schedule,
        slot: Slot,
        endMinute: Int,
        inverted: Bool
    ) -> Bool {
        let windows = schedule.windows
        if inverted {
            guard ScheduleCalendarLogic.slotInCalendar(schedule.calendar, slot: slot) else {
                return false
            }
            for w in windows {
                if exceptWindowMatchesRange(
                    window: w,
                    schedule: schedule,
                    slot: slot,
                    endMinute: endMinute
                ) {
                    return false
                }
            }
            return true
        }
        for w in windows {
            if windowMatchesSlotInRange(
                window: w,
                schedule: schedule,
                slot: slot,
                endMinute: endMinute
            ) {
                return true
            }
        }
        return false
    }

    nonisolated static func overlapsMembership(
        _ schedule: Schedule?,
        slot: Slot
    ) -> Bool {
        guard let schedule, schedule.status != .failed else { return false }

        if schedule.status == .anytime {
            return ScheduleCalendarLogic.slotInCalendar(schedule.calendar, slot: slot)
        }

        if schedule.status == .ok || schedule.status == .partial {
            if schedule.windows.isEmpty { return false }
            return matchesWithWindows(
                schedule: schedule,
                slot: slot,
                inverted: schedule.inverted == true
            )
        }

        return false
    }

    nonisolated static func overlapsMembershipInRange(
        _ schedule: Schedule?,
        slot: Slot,
        endMinute: Int
    ) -> Bool {
        guard let schedule, schedule.status != .failed else { return false }

        if schedule.status == .anytime {
            return ScheduleCalendarLogic.slotInCalendar(schedule.calendar, slot: slot)
        }

        if schedule.status == .ok || schedule.status == .partial {
            if schedule.windows.isEmpty { return false }
            return matchesWithWindowsInRange(
                schedule: schedule,
                slot: slot,
                endMinute: endMinute,
                inverted: schedule.inverted == true
            )
        }

        return false
    }

    nonisolated static func membershipFullyCoversRange(
        _ schedule: Schedule,
        slot: Slot,
        endMinute: Int
    ) -> Bool {
        if schedule.status == .failed { return false }
        if schedule.status == .anytime {
            return ScheduleCalendarLogic.slotInCalendar(schedule.calendar, slot: slot)
        }

        let windows = schedule.windows
        if windows.isEmpty { return false }

        if schedule.inverted == true {
            guard ScheduleCalendarLogic.slotInCalendar(schedule.calendar, slot: slot) else {
                return false
            }
            for w in windows {
                if exceptWindowMatchesRange(
                    window: w,
                    schedule: schedule,
                    slot: slot,
                    endMinute: endMinute
                ) {
                    return false
                }
            }
            return true
        }

        let qStart = slot.minuteOfDay
        let qEnd = endMinute
        let day = slot.dayOfWeek

        for w in windows {
            guard ScheduleCalendarLogic.slotInCalendar(
                effectiveCalendar(window: w, schedule: schedule),
                slot: slot
            ) else { continue }
            guard w.days.contains(day) else { continue }
            if holidayExcludesWindow(schedule: schedule, slot: slot) { continue }
            if rangeFullyInsideWindow(
                qStart: qStart,
                qEnd: qEnd,
                wStart: w.startMinute,
                wEnd: w.endMinute,
                crossesMidnight: w.crossesMidnight
            ) {
                return true
            }
        }
        return false
    }
}
