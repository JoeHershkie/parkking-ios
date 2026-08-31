import Foundation

enum TimeMode: String, Sendable, Equatable, Hashable {
    case now
    case custom
}

enum DurationPreset: Sendable, Equatable, Hashable {
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
    nonisolated static let durationPresets = [30, 60, 120, 180]
    nonisolated static let minDurationMinutes = 1
    nonisolated static let maxDurationMinutes = 720

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
                label: formatSlotLabel(slot, endMinuteOfDay: nil, now: now, timeZone: timeZone)
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
            label: formatSlotLabel(slot, endMinuteOfDay: effectiveEndMinute, now: now, timeZone: timeZone)
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

    nonisolated static func clampDuration(_ minutes: Int) -> Int {
        min(maxDurationMinutes, max(minDurationMinutes, minutes))
    }

    nonisolated static func preset(for minutes: Int) -> DurationPreset {
        durationPresets.contains(minutes) ? .minutes(minutes) : .custom
    }

    nonisolated static func date(
        fromTorontoDateString value: String,
        minuteOfDay: Int,
        timeZone: TimeZone = torontoTimeZone
    ) -> Date {
        let parts = value.split(separator: "-").compactMap { Int($0) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var components = DateComponents()
        components.year = parts.count > 0 ? parts[0] : 1970
        components.month = parts.count > 1 ? parts[1] : 1
        components.day = parts.count > 2 ? parts[2] : 1
        components.hour = minuteOfDay / 60
        components.minute = minuteOfDay % 60
        components.second = 0
        return calendar.date(from: components) ?? Date()
    }

    nonisolated static func torontoDateString(
        from date: Date,
        timeZone: TimeZone = torontoTimeZone
    ) -> String {
        slotToDateString(slotFromDate(date, timeZone: timeZone))
    }

    nonisolated static func minuteOfDay(
        from date: Date,
        timeZone: TimeZone = torontoTimeZone
    ) -> Int {
        slotFromDate(date, timeZone: timeZone).minuteOfDay
    }

    nonisolated static func draftCrossesMidnight(
        _ query: TimeQuery,
        now: Date = Date(),
        timeZone: TimeZone = torontoTimeZone
    ) -> Bool {
        let start: Int
        if query.mode == .now {
            start = slotFromDate(now, timeZone: timeZone).minuteOfDay
        } else {
            start = query.startMinute
        }
        return start + query.requestedDurationMinutes > midnightMinute
    }

    nonisolated static func formatTime(_ minuteOfDay: Int) -> String {
        let hour24 = minuteOfDay / 60
        let minute = minuteOfDay % 60
        let hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12
        let ampm = hour24 < 12 ? "am" : "pm"
        return String(format: "%d:%02d%@", hour12, minute, ampm)
    }

    nonisolated static func formatSlotLabel(
        _ slot: Slot,
        endMinuteOfDay: Int?,
        now: Date = Date(),
        timeZone: TimeZone = torontoTimeZone
    ) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let nowComponents = calendar.dateComponents([.year, .month, .day], from: now)
        let nowYear = nowComponents.year ?? 2026
        let slotYear = slot.year ?? nowYear

        var slotComponents = DateComponents()
        slotComponents.year = slotYear
        slotComponents.month = slot.month
        slotComponents.day = slot.dayOfMonth

        let startOfNow = calendar.date(from: nowComponents) ?? now
        let startOfSlot = calendar.date(from: slotComponents) ?? now
        let daysDifference = calendar.dateComponents([.day], from: startOfNow, to: startOfSlot).day ?? 0

        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let dayName = dayNames[max(0, min(6, slot.dayOfWeek))]

        let datePrefix: String
        if daysDifference == 0 {
            datePrefix = "Today"
        } else if daysDifference >= 1 && daysDifference <= 6 {
            datePrefix = dayName
        } else if slotYear == nowYear {
            datePrefix = String(format: "%@ %02d-%02d", dayName, slot.month, slot.dayOfMonth)
        } else {
            datePrefix = String(format: "%@ %04d-%02d-%02d", dayName, slotYear, slot.month, slot.dayOfMonth)
        }

        let startFormatted = formatTime(slot.minuteOfDay)
        if let endMinuteOfDay, endMinuteOfDay > slot.minuteOfDay {
            let endFormatted = formatTime(endMinuteOfDay)
            return "\(datePrefix) from \(startFormatted) - \(endFormatted)"
        } else {
            return "\(datePrefix) from \(startFormatted)"
        }
    }
}
