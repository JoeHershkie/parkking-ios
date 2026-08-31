import Foundation

nonisolated enum ScheduleStatus: String, Sendable, Codable, Equatable {
    case anytime
    case ok
    case partial
    case failed
    case unknown

    nonisolated init(raw: String?) {
        guard let raw, let value = ScheduleStatus(rawValue: raw) else {
            self = .unknown
            return
        }
        self = value
    }
}

nonisolated enum ScheduleCategory: String, Sendable, Codable, Equatable {
    case noParking = "no_parking"
    case noStopping = "no_stopping"
    case noStanding = "no_standing"
    case restrictedPeriods = "restricted_periods"
    case unknown

    nonisolated init(raw: String?) {
        guard let raw, let value = ScheduleCategory(rawValue: raw) else {
            self = .unknown
            return
        }
        self = value
    }

    nonisolated var rawStorage: String {
        switch self {
        case .unknown: return "unknown"
        default: return rawValue
        }
    }
}

nonisolated enum FilterPolarity: String, Sendable, Codable, Equatable {
    case restricted
    case permitted
    case notPermitted = "not_permitted"
    case unknown
    case inactive
    case partial
}

nonisolated struct Slot: Sendable, Hashable, Codable, Equatable {
    /// 0 = Sunday … 6 = Saturday
    var dayOfWeek: Int
    var minuteOfDay: Int
    var month: Int
    var dayOfMonth: Int
    var year: Int?

    nonisolated init(
        dayOfWeek: Int,
        minuteOfDay: Int,
        month: Int,
        dayOfMonth: Int,
        year: Int? = nil
    ) {
        self.dayOfWeek = dayOfWeek
        self.minuteOfDay = minuteOfDay
        self.month = month
        self.dayOfMonth = dayOfMonth
        self.year = year
    }
}

nonisolated struct CalendarMonthRange: Sendable, Hashable, Codable, Equatable {
    var startMonth: Int
    var startDay: Int
    var endMonth: Int
    var endDay: Int

    nonisolated init(startMonth: Int, startDay: Int, endMonth: Int, endDay: Int) {
        self.startMonth = startMonth
        self.startDay = startDay
        self.endMonth = endMonth
        self.endDay = endDay
    }
}

nonisolated enum DayOfMonthEnd: Sendable, Hashable, Equatable {
    case day(Int)
    case last
}

nonisolated struct CalendarDayOfMonthRange: Sendable, Hashable, Equatable {
    var start: Int
    var end: DayOfMonthEnd

    nonisolated init(start: Int, end: DayOfMonthEnd) {
        self.start = start
        self.end = end
    }
}

nonisolated struct ScheduleCalendar: Sendable, Hashable, Equatable {
    var monthRanges: [CalendarMonthRange]?
    var dayOfMonthRanges: [CalendarDayOfMonthRange]?
    var months: [Int]?

    nonisolated init(
        monthRanges: [CalendarMonthRange]? = nil,
        dayOfMonthRanges: [CalendarDayOfMonthRange]? = nil,
        months: [Int]? = nil
    ) {
        self.monthRanges = monthRanges
        self.dayOfMonthRanges = dayOfMonthRanges
        self.months = months
    }
}

nonisolated struct TimeWindow: Sendable, Hashable, Equatable {
    var days: [Int]
    var startMinute: Int
    var endMinute: Int
    var crossesMidnight: Bool?
    var calendar: ScheduleCalendar?

    nonisolated init(
        days: [Int],
        startMinute: Int,
        endMinute: Int,
        crossesMidnight: Bool? = nil,
        calendar: ScheduleCalendar? = nil
    ) {
        self.days = days
        self.startMinute = startMinute
        self.endMinute = endMinute
        self.crossesMidnight = crossesMidnight
        self.calendar = calendar
    }
}

nonisolated struct ScheduleFlags: Sendable, Hashable, Codable, Equatable {
    var exceptPublicHolidays: Bool?

    nonisolated init(exceptPublicHolidays: Bool? = nil) {
        self.exceptPublicHolidays = exceptPublicHolidays
    }

    enum CodingKeys: String, CodingKey {
        case exceptPublicHolidays
    }
}

nonisolated struct Schedule: Sendable, Hashable, Equatable {
    var v: Int
    var status: ScheduleStatus
    var source: String
    var windows: [TimeWindow]
    var calendar: ScheduleCalendar?
    var flags: ScheduleFlags?
    var inverted: Bool?
    var unparsedClauses: [String]?

    nonisolated init(
        v: Int = 1,
        status: ScheduleStatus,
        source: String,
        windows: [TimeWindow] = [],
        calendar: ScheduleCalendar? = nil,
        flags: ScheduleFlags? = nil,
        inverted: Bool? = nil,
        unparsedClauses: [String]? = nil
    ) {
        self.v = v
        self.status = status
        self.source = source
        self.windows = windows
        self.calendar = calendar
        self.flags = flags
        self.inverted = inverted
        self.unparsedClauses = unparsedClauses
    }
}

nonisolated struct SlotEvaluation: Sendable, Equatable {
    var visible: Bool
    var polarity: FilterPolarity
    var unparsed: Bool
    var partial: Bool?
    var failed: Bool?

    nonisolated init(
        visible: Bool,
        polarity: FilterPolarity,
        unparsed: Bool,
        partial: Bool? = nil,
        failed: Bool? = nil
    ) {
        self.visible = visible
        self.polarity = polarity
        self.unparsed = unparsed
        self.partial = partial
        self.failed = failed
    }
}

// MARK: - Codable bridging for flexible GeoJSON / fixtures

extension CalendarDayOfMonthRange: Codable {
    enum CodingKeys: String, CodingKey {
        case start
        case end
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        start = try container.decode(Int.self, forKey: .start)
        if let endInt = try? container.decode(Int.self, forKey: .end) {
            end = .day(endInt)
        } else if let endString = try? container.decode(String.self, forKey: .end),
                  endString == "last"
        {
            end = .last
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .end,
                in: container,
                debugDescription: "Expected Int or \"last\""
            )
        }
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(start, forKey: .start)
        switch end {
        case .day(let value):
            try container.encode(value, forKey: .end)
        case .last:
            try container.encode("last", forKey: .end)
        }
    }
}

extension ScheduleCalendar: Codable {
    enum CodingKeys: String, CodingKey {
        case monthRanges
        case dayOfMonthRanges
        case months
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        monthRanges = try container.decodeIfPresent([CalendarMonthRange].self, forKey: .monthRanges)
        dayOfMonthRanges = try container.decodeIfPresent(
            [CalendarDayOfMonthRange].self,
            forKey: .dayOfMonthRanges
        )
        months = try container.decodeIfPresent([Int].self, forKey: .months)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(monthRanges, forKey: .monthRanges)
        try container.encodeIfPresent(dayOfMonthRanges, forKey: .dayOfMonthRanges)
        try container.encodeIfPresent(months, forKey: .months)
    }
}

extension TimeWindow: Codable {
    enum CodingKeys: String, CodingKey {
        case days
        case startMinute
        case endMinute
        case crossesMidnight
        case calendar
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        days = try container.decode([Int].self, forKey: .days)
        startMinute = try container.decode(Int.self, forKey: .startMinute)
        endMinute = try container.decode(Int.self, forKey: .endMinute)
        crossesMidnight = try container.decodeIfPresent(Bool.self, forKey: .crossesMidnight)
        calendar = try container.decodeIfPresent(ScheduleCalendar.self, forKey: .calendar)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(days, forKey: .days)
        try container.encode(startMinute, forKey: .startMinute)
        try container.encode(endMinute, forKey: .endMinute)
        try container.encodeIfPresent(crossesMidnight, forKey: .crossesMidnight)
        try container.encodeIfPresent(calendar, forKey: .calendar)
    }
}

extension Schedule: Codable {
    enum CodingKeys: String, CodingKey {
        case v
        case status
        case source
        case windows
        case calendar
        case flags
        case inverted
        case unparsedClauses
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        v = try container.decodeIfPresent(Int.self, forKey: .v) ?? 1
        let statusRaw = try container.decodeIfPresent(String.self, forKey: .status)
        status = ScheduleStatus(raw: statusRaw)
        source = try container.decodeIfPresent(String.self, forKey: .source) ?? ""
        windows = try container.decodeIfPresent([TimeWindow].self, forKey: .windows) ?? []
        calendar = try container.decodeIfPresent(ScheduleCalendar.self, forKey: .calendar)
        flags = try container.decodeIfPresent(ScheduleFlags.self, forKey: .flags)
        inverted = try container.decodeIfPresent(Bool.self, forKey: .inverted)
        unparsedClauses = try container.decodeIfPresent([String].self, forKey: .unparsedClauses)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(v, forKey: .v)
        try container.encode(status.rawValue, forKey: .status)
        try container.encode(source, forKey: .source)
        try container.encode(windows, forKey: .windows)
        try container.encodeIfPresent(calendar, forKey: .calendar)
        try container.encodeIfPresent(flags, forKey: .flags)
        try container.encodeIfPresent(inverted, forKey: .inverted)
        try container.encodeIfPresent(unparsedClauses, forKey: .unparsedClauses)
    }
}

// MARK: - Dictionary decoding (GeoJSON walk, no JSON round-trip)

extension Schedule {
    nonisolated init?(dictionary obj: [String: Any]) {
        self.init(
            v: ScheduleJSON.intValue(obj["v"]) ?? 1,
            status: ScheduleStatus(raw: ScheduleJSON.stringValue(obj["status"])),
            source: ScheduleJSON.stringValue(obj["source"]) ?? "",
            windows: ScheduleJSON.timeWindows(obj["windows"]),
            calendar: ScheduleJSON.calendar(obj["calendar"]),
            flags: ScheduleJSON.flags(obj["flags"]),
            inverted: ScheduleJSON.boolValue(obj["inverted"]),
            unparsedClauses: ScheduleJSON.stringList(obj["unparsedClauses"])
        )
    }
}

private enum ScheduleJSON {
    nonisolated static func stringValue(_ any: Any?) -> String? {
        if let s = any as? String { return s }
        if any is NSNull { return nil }
        if let n = any as? NSNumber { return n.stringValue }
        return nil
    }

    nonisolated static func intValue(_ any: Any?) -> Int? {
        if let i = any as? Int { return i }
        if let d = any as? Double { return Int(d.rounded()) }
        if let n = any as? NSNumber { return n.intValue }
        if let s = any as? String, let d = Double(s) { return Int(d.rounded()) }
        return nil
    }

    nonisolated static func boolValue(_ any: Any?) -> Bool? {
        if any is NSNull || any == nil { return nil }
        if let b = any as? Bool { return b }
        if let n = any as? NSNumber { return n.boolValue }
        if let s = any as? String {
            let lower = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if ["true", "1", "yes"].contains(lower) { return true }
            if ["false", "0", "no"].contains(lower) { return false }
        }
        return nil
    }

    nonisolated static func stringList(_ any: Any?) -> [String]? {
        if any is NSNull || any == nil { return nil }
        if let arr = any as? [Any] {
            return arr.compactMap { stringValue($0) }
        }
        return nil
    }

    nonisolated static func intList(_ any: Any?) -> [Int]? {
        if any is NSNull || any == nil { return nil }
        if let arr = any as? [Any] {
            return arr.compactMap { intValue($0) }
        }
        return nil
    }

    nonisolated static func timeWindows(_ any: Any?) -> [TimeWindow] {
        guard let arr = any as? [Any] else { return [] }
        return arr.compactMap { item in
            guard let obj = item as? [String: Any] else { return nil }
            return timeWindow(obj)
        }
    }

    nonisolated static func timeWindow(_ obj: [String: Any]) -> TimeWindow? {
        guard let days = intList(obj["days"]),
              let startMinute = intValue(obj["startMinute"]),
              let endMinute = intValue(obj["endMinute"])
        else { return nil }
        return TimeWindow(
            days: days,
            startMinute: startMinute,
            endMinute: endMinute,
            crossesMidnight: boolValue(obj["crossesMidnight"]),
            calendar: calendar(obj["calendar"])
        )
    }

    nonisolated static func calendar(_ any: Any?) -> ScheduleCalendar? {
        guard let obj = any as? [String: Any] else { return nil }
        return ScheduleCalendar(
            monthRanges: monthRanges(obj["monthRanges"]),
            dayOfMonthRanges: dayOfMonthRanges(obj["dayOfMonthRanges"]),
            months: intList(obj["months"])
        )
    }

    nonisolated static func monthRanges(_ any: Any?) -> [CalendarMonthRange]? {
        guard let arr = any as? [Any] else { return nil }
        let ranges: [CalendarMonthRange] = arr.compactMap { item in
            guard let obj = item as? [String: Any],
                  let startMonth = intValue(obj["startMonth"]),
                  let startDay = intValue(obj["startDay"]),
                  let endMonth = intValue(obj["endMonth"]),
                  let endDay = intValue(obj["endDay"])
            else { return nil }
            return CalendarMonthRange(
                startMonth: startMonth,
                startDay: startDay,
                endMonth: endMonth,
                endDay: endDay
            )
        }
        return ranges
    }

    nonisolated static func dayOfMonthRanges(_ any: Any?) -> [CalendarDayOfMonthRange]? {
        guard let arr = any as? [Any] else { return nil }
        let ranges: [CalendarDayOfMonthRange] = arr.compactMap { item in
            guard let obj = item as? [String: Any],
                  let start = intValue(obj["start"])
            else { return nil }
            let end: DayOfMonthEnd
            if let endInt = intValue(obj["end"]) {
                end = .day(endInt)
            } else if let endString = stringValue(obj["end"]), endString == "last" {
                end = .last
            } else {
                return nil
            }
            return CalendarDayOfMonthRange(start: start, end: end)
        }
        return ranges
    }

    nonisolated static func flags(_ any: Any?) -> ScheduleFlags? {
        guard let obj = any as? [String: Any] else { return nil }
        return ScheduleFlags(exceptPublicHolidays: boolValue(obj["exceptPublicHolidays"]))
    }
}
