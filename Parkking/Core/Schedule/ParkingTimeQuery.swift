import Foundation

enum TimeMode: String, Sendable, Equatable {
    case now
    case custom
}

enum DurationPreset: Sendable, Equatable {
    case minutes(Int)
    case custom
}

struct TimeQuery: Sendable, Equatable {
    var mode: TimeMode
    /// Calendar date YYYY-MM-DD when mode is custom; ignored when now.
    var date: String
    /// Start minute of day when mode is custom.
    var startMinute: Int
    /// Requested duration in minutes (preserved even when truncated).
    var requestedDurationMinutes: Int
    var durationPreset: DurationPreset

    nonisolated init(
        mode: TimeMode,
        date: String,
        startMinute: Int,
        requestedDurationMinutes: Int,
        durationPreset: DurationPreset
    ) {
        self.mode = mode
        self.date = date
        self.startMinute = startMinute
        self.requestedDurationMinutes = requestedDurationMinutes
        self.durationPreset = durationPreset
    }
}

struct ResolvedTimeQuery: Sendable, Equatable {
    var slot: Slot
    /// Effective end minute of day, or nil when duration is zero/point check.
    var effectiveEndMinute: Int?
    var requestedDurationMinutes: Int
    var truncatedAtMidnight: Bool
    var label: String

    nonisolated init(
        slot: Slot,
        effectiveEndMinute: Int?,
        requestedDurationMinutes: Int,
        truncatedAtMidnight: Bool,
        label: String
    ) {
        self.slot = slot
        self.effectiveEndMinute = effectiveEndMinute
        self.requestedDurationMinutes = requestedDurationMinutes
        self.truncatedAtMidnight = truncatedAtMidnight
        self.label = label
    }
}

enum ParkingTimeQuery {
    nonisolated static let midnightMinute = 23 * 60 + 59
    nonisolated static let midnightWarning =
        "Checked through midnight only; later rules were not evaluated."
    nonisolated static let torontoTimeZone =
        TimeZone(identifier: "America/Toronto") ?? .gmt

    nonisolated static func createNowTimeQuery(
        durationMinutes: Int = 60,
        preset: DurationPreset = .minutes(60),
        now: Date = Date(),
        timeZone: TimeZone = torontoTimeZone
    ) -> TimeQuery {
        let slot = slotFromDate(now, timeZone: timeZone)
        return TimeQuery(
            mode: .now,
            date: slotToDateString(slot),
            startMinute: slot.minuteOfDay,
            requestedDurationMinutes: durationMinutes,
            durationPreset: preset
        )
    }

    nonisolated static func resolveTimeQuery(
        _ query: TimeQuery,
        now: Date = Date(),
        timeZone: TimeZone = torontoTimeZone
    ) -> ResolvedTimeQuery {
        let slot: Slot
        if query.mode == .now {
            slot = slotFromDate(now, timeZone: timeZone)
        } else {
            slot = slotFromDateString(query.date, minuteOfDay: query.startMinute, timeZone: timeZone)
        }

        let requested = max(0, query.requestedDurationMinutes)
        if requested <= 0 {
            return ResolvedTimeQuery(
                slot: slot,
                effectiveEndMinute: nil,
                requestedDurationMinutes: requested,
                truncatedAtMidnight: false,
                label: formatSlotLabel(slot, endMinuteOfDay: nil)
            )
        }

        let rawEnd = slot.minuteOfDay + requested
        let truncatedAtMidnight = rawEnd > midnightMinute
        let effectiveEnd = truncatedAtMidnight ? midnightMinute : rawEnd
        let effectiveEndMinute = effectiveEnd > slot.minuteOfDay ? effectiveEnd : nil

        return ResolvedTimeQuery(
            slot: slot,
            effectiveEndMinute: effectiveEndMinute,
            requestedDurationMinutes: requested,
            truncatedAtMidnight: truncatedAtMidnight,
            label: formatSlotLabel(slot, endMinuteOfDay: effectiveEndMinute)
        )
    }

    nonisolated static func formatDurationLabel(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        if minutes % 60 == 0 {
            let hours = minutes / 60
            return hours == 1 ? "1h" : "\(hours)h"
        }
        let h = minutes / 60
        let m = minutes % 60
        return "\(h)h \(m)m"
    }

    nonisolated static func formatTimeQueryChip(
        query: TimeQuery,
        resolved: ResolvedTimeQuery
    ) -> String {
        let startH = resolved.slot.minuteOfDay / 60
        let startM = resolved.slot.minuteOfDay % 60
        let start = String(format: "%02d:%02d", startH, startM)
        let dur = formatDurationLabel(query.requestedDurationMinutes)
        if query.mode == .now {
            return "Now · \(dur)"
        }
        return "\(start) · \(dur)"
    }

    nonisolated static func slotFromDate(
        _ date: Date,
        timeZone: TimeZone = torontoTimeZone
    ) -> Slot {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents(
            [.year, .month, .day, .weekday, .hour, .minute],
            from: date
        )
        // Foundation weekday: 1=Sunday … 7=Saturday → JS getDay 0=Sunday
        let dayOfWeek = (parts.weekday ?? 1) - 1
        let minuteOfDay = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        return Slot(
            dayOfWeek: dayOfWeek,
            minuteOfDay: minuteOfDay,
            month: parts.month ?? 1,
            dayOfMonth: parts.day ?? 1,
            year: parts.year
        )
    }

    nonisolated static func slotToDateString(_ slot: Slot) -> String {
        let y = slot.year ?? Calendar(identifier: .gregorian).component(.year, from: Date())
        return String(format: "%04d-%02d-%02d", y, slot.month, slot.dayOfMonth)
    }

    nonisolated static func slotFromDateString(
        _ value: String,
        minuteOfDay: Int,
        timeZone: TimeZone = torontoTimeZone
    ) -> Slot {
        let parts = value.split(separator: "-").compactMap { Int($0) }
        let y = parts.count > 0 ? parts[0] : 1970
        let m = parts.count > 1 ? parts[1] : 1
        let d = parts.count > 2 ? parts[2] : 1
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var components = DateComponents()
        components.year = y
        components.month = m
        components.day = d
        let date = calendar.date(from: components) ?? Date()
        let weekday = calendar.component(.weekday, from: date) - 1
        return Slot(
            dayOfWeek: weekday,
            minuteOfDay: minuteOfDay,
            month: m,
            dayOfMonth: d,
            year: y
        )
    }

    nonisolated static func formatSlotLabel(
        _ slot: Slot,
        endMinuteOfDay: Int?
    ) -> String {
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let h = slot.minuteOfDay / 60
        let m = slot.minuteOfDay % 60
        let startTime = String(format: "%02d:%02d", h, m)
        let day = dayNames[max(0, min(6, slot.dayOfWeek))]
        let datePart = slotToDateString(slot)

        guard let endMinuteOfDay, endMinuteOfDay > slot.minuteOfDay else {
            return "\(day) \(datePart) \(startTime)"
        }

        let eh = endMinuteOfDay / 60
        let em = endMinuteOfDay % 60
        let endTime = String(format: "%02d:%02d", eh, em)
        return "\(day) \(datePart) \(startTime)–\(endTime)"
    }
}
