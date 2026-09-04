import Foundation

enum ScheduleEvaluator {
    nonisolated static func isRestrictedCategory(_ category: String) -> Bool {
        switch category {
        case "no_parking",
             "no_stopping",
             "no_standing",
             "snow_route",
             "snow_streetcar",
             "winter_maintenance",
             "commercial_loading",
             "delivery_loading",
             "passenger_loading",
             "car_share",
             "ev_charging",
             "taxicab_stand":
            return true
        default:
            return category.contains("snow") || category.contains("winter")
        }
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

    nonisolated static func isSeasonalWinterOrSnowText(_ text: String) -> Bool {
        let lower = text.lowercased()
        if lower.contains("snow") || lower.contains("winter") {
            return true
        }
        if (lower.contains("dec") || lower.contains("nov")) && (lower.contains("mar") || lower.contains("apr")) {
            return true
        }
        if lower.contains("dec. 1") || lower.contains("dec 1") || lower.contains("december") {
            return true
        }
        return false
    }

    nonisolated static func isSeasonalWinterOrSnowRule(
        props: ParkingProperties,
        schedule: Schedule
    ) -> Bool {
        if schedule.condition == "major_snowstorm_declared"
            || schedule.isSnowRoute == true
            || props.isSnowRoute == true
            || props.scheduleCategory == "winter_maintenance"
            || props.scheduleCategory == "snow_route"
            || props.scheduleCategory == "snow_streetcar"
            || props.scheduleCategory.contains("snow")
            || props.scheduleCategory.contains("winter")
            || isSeasonalWinterOrSnowText(props.rule)
            || isSeasonalWinterOrSnowText(schedule.source)
        {
            return true
        }
        if let cond = schedule.condition, isSeasonalWinterOrSnowText(cond) {
            return true
        }
        if let calendar = schedule.calendar, isWinterCalendar(calendar) {
            return true
        }
        for window in schedule.windows {
            if let cal = window.calendar, isWinterCalendar(cal) {
                return true
            }
        }
        return false
    }

    nonisolated private static func isWinterCalendar(_ calendar: ScheduleCalendar) -> Bool {
        if let ranges = calendar.monthRanges {
            for r in ranges {
                if r.startMonth > r.endMonth {
                    return true
                }
                if r.startMonth == 12 || r.startMonth == 1 || r.startMonth == 2 || r.startMonth == 11 {
                    if r.endMonth <= 4 || r.endMonth == 12 {
                        return true
                    }
                }
                if r.endMonth == 3 || r.endMonth == 2 || r.endMonth == 1 {
                    return true
                }
            }
        }
        if let months = calendar.months {
            if months.allSatisfy({ [11, 12, 1, 2, 3, 4].contains($0) }) {
                return true
            }
            if months.contains(12) || months.contains(1) || months.contains(2) {
                let winterCount = months.filter { [11, 12, 1, 2, 3].contains($0) }.count
                if Double(winterCount) / Double(months.count) >= 0.5 && months.count <= 6 {
                    return true
                }
            }
        }
        return false
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
            if props.isSnowRoute == true
                || props.scheduleCategory == "winter_maintenance"
                || props.scheduleCategory == "snow_route"
                || props.scheduleCategory == "snow_streetcar"
                || props.scheduleCategory.contains("snow")
                || props.scheduleCategory.contains("winter")
                || isSeasonalWinterOrSnowText(props.rule)
            {
                return SlotEvaluation(visible: false, polarity: .inactive, unparsed: true)
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

        let overlaps = ScheduleMembership.overlapsMembership(schedule, slot: slot)
        let polarity = polarityFromOverlap(
            category: category,
            overlaps: overlaps,
            schedule: schedule
        )
        let isWinterSnow = isSeasonalWinterOrSnowRule(props: props, schedule: schedule)
        let visible = !(isWinterSnow && !overlaps && isRestrictedCategory(category))

        if schedule.status == .partial {
            return SlotEvaluation(
                visible: visible,
                polarity: polarity,
                unparsed: true,
                partial: true
            )
        }

        return SlotEvaluation(
            visible: visible,
            polarity: polarity,
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

        let isWinterSnow = isSeasonalWinterOrSnowRule(props: props, schedule: schedule)

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
            let visible = !(isWinterSnow && !overlaps && isRestrictedCategory(category))
            return SlotEvaluation(
                visible: visible,
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
        let visible = !(isWinterSnow && !overlaps && isRestrictedCategory(category))

        return SlotEvaluation(
            visible: visible,
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
        let isWinterSnow = isSeasonalWinterOrSnowRule(props: props, schedule: schedule)
        let visible = !(isWinterSnow && !overlaps && isRestrictedCategory(category))

        return SlotEvaluation(
            visible: visible,
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
