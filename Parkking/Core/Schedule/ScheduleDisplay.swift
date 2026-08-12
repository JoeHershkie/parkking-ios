import Foundation

struct ScheduleHint: Sendable, Equatable {
    enum Kind: String, Sendable, Equatable {
        case failed
        case partial
        case inverted
        case calendar
    }

    var kind: Kind
    var text: String
    var title: String?

    nonisolated init(kind: Kind, text: String, title: String? = nil) {
        self.kind = kind
        self.text = text
        self.title = title
    }
}

enum ScheduleDisplay {
    nonisolated private static let monthShort = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ]
    nonisolated private static let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    nonisolated static func formatCalendarSummary(_ calendar: ScheduleCalendar?) -> String? {
        guard let calendar else { return nil }
        var parts: [String] = []

        if let ranges = calendar.monthRanges, !ranges.isEmpty {
            for r in ranges {
                parts.append(
                    "\(formatMonthDay(month: r.startMonth, day: r.startDay))–\(formatMonthDay(month: r.endMonth, day: r.endDay))"
                )
            }
        }

        if let ranges = calendar.dayOfMonthRanges, !ranges.isEmpty {
            for r in ranges {
                let endLabel: String
                switch r.end {
                case .last:
                    endLabel = "last"
                case .day(let value):
                    endLabel = String(value)
                }
                if case .day(let endDay) = r.end, r.start == endDay {
                    parts.append("\(ordinal(r.start)) of month")
                } else if endLabel == String(r.start) {
                    parts.append("\(ordinal(r.start)) of month")
                } else {
                    let endOrd =
                        endLabel == "last" ? "last" : ordinal(Int(endLabel) ?? r.start)
                    parts.append("\(ordinal(r.start))–\(endOrd) of month")
                }
            }
        }

        if let months = calendar.months, !months.isEmpty {
            parts.append(months.map { monthShort[$0 - 1] }.joined(separator: ", "))
        }

        return parts.isEmpty ? nil : parts.joined(separator: "; ")
    }

    nonisolated static func formatExceptWindowsSummary(_ schedule: Schedule) -> String? {
        let windows = schedule.windows
        guard !windows.isEmpty else { return nil }
        return windows.map(formatWindowBrief).joined(separator: "; ")
    }

    nonisolated static func scheduleStatusHints(_ schedule: Schedule?) -> [ScheduleHint] {
        guard let schedule else { return [] }
        var hints: [ScheduleHint] = []

        if schedule.status == .failed {
            hints.append(
                ScheduleHint(
                    kind: .failed,
                    text: "Schedule not parsed — times may be incomplete"
                )
            )
            return hints
        }

        if schedule.status == .partial {
            let title =
                (schedule.unparsedClauses?.isEmpty == false)
                ? schedule.unparsedClauses?.joined(separator: "; ")
                : nil
            hints.append(ScheduleHint(kind: .partial, text: "Partially parsed", title: title))
        }

        if schedule.inverted == true {
            let except = formatExceptWindowsSummary(schedule)
            hints.append(
                ScheduleHint(
                    kind: .inverted,
                    text: except.map { "Applies except during \($0)" }
                        ?? "Applies except during listed periods"
                )
            )
        }

        let cal =
            formatCalendarSummary(schedule.calendar)
            ?? schedule.windows.lazy
            .compactMap { formatCalendarSummary($0.calendar) }
            .first

        if let cal {
            hints.append(ScheduleHint(kind: .calendar, text: cal))
        }

        return hints
    }

    // MARK: - Private

    nonisolated private static func formatMonthDay(month: Int, day: Int) -> String {
        let idx = max(0, min(11, month - 1))
        return "\(monthShort[idx]) \(day)"
    }

    nonisolated private static func ordinal(_ n: Int) -> String {
        // Match JS: const s = ['th','st','nd','rd']; const v = n % 100;
        // return `${n}${s[(v - 20) % 10] ?? s[v] ?? s[0]}`
        let s = ["th", "st", "nd", "rd"]
        let v = n % 100
        let fromMod = ((v - 20) % 10 + 10) % 10 // positive mod for negative (v-20)
        // JS `%` truncates toward zero; for v < 20, (v-20)%10 is negative → undefined → s[v]
        let jsMod = (v - 20) % 10
        let suffix: String
        if jsMod >= 0, jsMod < s.count {
            suffix = s[jsMod]
        } else if v >= 0, v < s.count {
            suffix = s[v]
        } else {
            suffix = s[0]
        }
        _ = fromMod
        return "\(n)\(suffix)"
    }

    nonisolated private static func formatMinute(_ minute: Int) -> String {
        String(format: "%02d:%02d", minute / 60, minute % 60)
    }

    nonisolated private static func formatDays(_ days: [Int]) -> String {
        if days.count == 7 { return "daily" }
        if days.count == 5, [1, 2, 3, 4, 5].allSatisfy({ days.contains($0) }) {
            return "Mon–Fri"
        }
        return days.map { dayNames[$0] }.joined(separator: ", ")
    }

    nonisolated private static func formatWindowBrief(_ w: TimeWindow) -> String {
        let time =
            (w.startMinute == 0 && w.endMinute >= 1439)
            ? "all day"
            : "\(formatMinute(w.startMinute))–\(formatMinute(w.endMinute))"
        return "\(formatDays(w.days)) \(time)"
    }
}
