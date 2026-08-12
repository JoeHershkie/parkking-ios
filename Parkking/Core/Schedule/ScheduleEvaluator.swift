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
        schedule: Schedule
    ) -> FilterPolarity {
        if schedule.status == .anytime {
            if category == "restricted_periods" { return .permitted }
            return .restricted
        }
        if category == "restricted_periods" {
            return fullyCovered ? .permitted : .notPermitted
        }
        if isRestrictedCategory(category) {
            return overlaps ? .restricted : .inactive
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

        if schedule.status == .partial {
            let overlaps = ScheduleMembership.overlapsMembershipInRange(
                schedule,
                slot: slot,
                endMinute: endMinuteOfDay
            )
            let fullyCovered =
                category == "restricted_periods"
                ? ScheduleMembership.membershipFullyCoversRange(
                    schedule,
                    slot: slot,
                    endMinute: endMinuteOfDay
                )
                : false
            return SlotEvaluation(
                visible: true,
                polarity: polarityFromRangeOverlap(
                    category: category,
                    overlaps: overlaps,
                    fullyCovered: fullyCovered,
                    schedule: schedule
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
                schedule: schedule
            ),
            unparsed: false
        )
    }
}
