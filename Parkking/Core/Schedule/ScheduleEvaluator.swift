import Foundation

enum ScheduleEvaluator {
    nonisolated private static func isRestrictedCategory(_ category: String) -> Bool {
        category == "no_parking" || category == "no_stopping" || category == "no_standing"
    }

    nonisolated private static func polarityFromOverlap(
        category: String,
        overlaps: Bool,
        schedule: Schedule
    ) -> FilterPolarity {
        if schedule.status == .anytime {
            if category == "restricted_periods" { return .permitted }
            return .restricted
        }
        if category == "restricted_periods" {
            return overlaps ? .permitted : .notPermitted
        }
        if isRestrictedCategory(category) {
            return overlaps ? .restricted : .inactive
        }
        return .inactive
    }

    nonisolated private static func polarityFromRangeOverlap(
        category: String,
        overlaps: Bool,
        fullyCovered: Bool,
        schedule: Schedule,
        maxMinutes: Int? = nil,
        requestedDurationMinutes: Int? = nil
    ) -> FilterPolarity {
        let maxStayViolated: Bool
        if let maxMinutes, maxMinutes > 0, let requestedDurationMinutes, requestedDurationMinutes > maxMinutes {
            maxStayViolated = true
        } else {
            maxStayViolated = false
        }

        if schedule.status == .anytime {
            if category == "restricted_periods" {
                return maxStayViolated ? .partial : .permitted
            }
            return .restricted
        }
        if category == "restricted_periods" {
            if fullyCovered {
                return maxStayViolated ? .partial : .permitted
            }
            if overlaps { return .partial }
            return .notPermitted
        }
        if isRestrictedCategory(category) {
            if !overlaps { return .inactive }
            if fullyCovered { return .restricted }
            return .partial
        }
        return .inactive
    }

    nonisolated static func evaluateAtSlot(
        props: ParkingProperties,
        slot: Slot,
        includeUnknown: Bool
    ) -> SlotEvaluation {
        guard let schedule = props.schedule else {
            if !includeUnknown {
                return SlotEvaluation(visible: false, polarity: .unknown, unparsed: true)
            }
            return SlotEvaluation(visible: true, polarity: .unknown, unparsed: true)
        }

        let category = props.scheduleCategory

        if schedule.status == .failed {
            return SlotEvaluation(
                visible: true,
                polarity: .unknown,
                unparsed: true,
                failed: true
            )
        }

        if schedule.status == .partial {
            let overlaps = ScheduleMembership.overlapsMembership(schedule, slot: slot)
            return SlotEvaluation(
                visible: true,
                polarity: polarityFromOverlap(
                    category: category,
                    overlaps: overlaps,
                    schedule: schedule
                ),
                unparsed: true,
                partial: true
            )
        }

        let overlaps = ScheduleMembership.overlapsMembership(schedule, slot: slot)
        return SlotEvaluation(
            visible: true,
            polarity: polarityFromOverlap(
                category: category,
                overlaps: overlaps,
                schedule: schedule
            ),
            unparsed: false
        )
    }

    nonisolated static func evaluateInRange(
        props: ParkingProperties,
        slot: Slot,
        endMinuteOfDay: Int?,
        includeUnknown: Bool
    ) -> SlotEvaluation {
        guard let endMinuteOfDay, endMinuteOfDay > slot.minuteOfDay else {
            return evaluateAtSlot(props: props, slot: slot, includeUnknown: includeUnknown)
        }

        guard let schedule = props.schedule else {
            if !includeUnknown {
                return SlotEvaluation(visible: false, polarity: .unknown, unparsed: true)
            }
            return SlotEvaluation(visible: true, polarity: .unknown, unparsed: true)
        }

        let category = props.scheduleCategory

        if schedule.status == .failed {
            return SlotEvaluation(
                visible: true,
                polarity: .unknown,
                unparsed: true,
                failed: true
            )
        }

        let requestedDurationMinutes = endMinuteOfDay - slot.minuteOfDay

        if schedule.status == .partial {
            let overlaps = ScheduleMembership.overlapsMembershipInRange(
                schedule,
                slot: slot,
                endMinute: endMinuteOfDay
            )
            let fullyCovered = ScheduleMembership.membershipFullyCoversRange(
                schedule,
                slot: slot,
                endMinute: endMinuteOfDay
            )
            return SlotEvaluation(
                visible: true,
                polarity: polarityFromRangeOverlap(
                    category: category,
                    overlaps: overlaps,
                    fullyCovered: fullyCovered,
                    schedule: schedule,
                    maxMinutes: props.maxMinutes,
                    requestedDurationMinutes: requestedDurationMinutes
                ),
                unparsed: true,
                partial: true
            )
        }

        let overlaps = ScheduleMembership.overlapsMembershipInRange(
            schedule,
            slot: slot,
            endMinute: endMinuteOfDay
        )
        let fullyCovered = ScheduleMembership.membershipFullyCoversRange(
            schedule,
            slot: slot,
            endMinute: endMinuteOfDay
        )

        return SlotEvaluation(
            visible: true,
            polarity: polarityFromRangeOverlap(
                category: category,
                overlaps: overlaps,
                fullyCovered: fullyCovered,
                schedule: schedule,
                maxMinutes: props.maxMinutes,
                requestedDurationMinutes: requestedDurationMinutes
            ),
            unparsed: false
        )
    }

    nonisolated static func evaluateQuery(
        props: ParkingProperties,
        query: ResolvedTimeQuery,
        includeUnknown: Bool
    ) -> SlotEvaluation {
        if !query.crossesMidnight {
            return evaluateInRange(
                props: props,
                slot: query.slot,
                endMinuteOfDay: query.effectiveEndMinute,
                includeUnknown: includeUnknown
            )
        }

        guard let schedule = props.schedule else {
            if !includeUnknown {
                return SlotEvaluation(visible: false, polarity: .unknown, unparsed: true)
            }
            return SlotEvaluation(visible: true, polarity: .unknown, unparsed: true)
        }

        let category = props.scheduleCategory
        if schedule.status == .failed {
            return SlotEvaluation(
                visible: true,
                polarity: .unknown,
                unparsed: true,
                failed: true
            )
        }

        guard let nextDaySlot = query.nextDaySlot, let nextDayEndMinute = query.nextDayEndMinute else {
            return evaluateInRange(
                props: props,
                slot: query.slot,
                endMinuteOfDay: query.effectiveEndMinute,
                includeUnknown: includeUnknown
            )
        }

        let isPartialSchedule = schedule.status == .partial

        let overlaps1 = ScheduleMembership.overlapsMembershipInRange(
            schedule,
            slot: query.slot,
            endMinute: 1440
        )
        let fullyCovered1 = ScheduleMembership.membershipFullyCoversRange(
            schedule,
            slot: query.slot,
            endMinute: 1440
        )

        let overlaps2 = ScheduleMembership.overlapsMembershipInRange(
            schedule,
            slot: nextDaySlot,
            endMinute: nextDayEndMinute
        )
        let fullyCovered2 = ScheduleMembership.membershipFullyCoversRange(
            schedule,
            slot: nextDaySlot,
            endMinute: nextDayEndMinute
        )

        let overlaps = overlaps1 || overlaps2
        let fullyCovered = fullyCovered1 && fullyCovered2

        return SlotEvaluation(
            visible: true,
            polarity: polarityFromRangeOverlap(
                category: category,
                overlaps: overlaps,
                fullyCovered: fullyCovered,
                schedule: schedule,
                maxMinutes: props.maxMinutes,
                requestedDurationMinutes: query.requestedDurationMinutes
            ),
            unparsed: isPartialSchedule,
            partial: isPartialSchedule ? true : nil
        )
    }
}
