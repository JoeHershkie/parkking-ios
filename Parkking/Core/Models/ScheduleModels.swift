import Foundation

enum ScheduleStatus: String, Sendable, Codable, Equatable {
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

enum ScheduleCategory: String, Sendable, Codable, Equatable {
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

enum FilterPolarity: String, Sendable, Codable, Equatable {
    case restricted
    case permitted
    case notPermitted = "not_permitted"
    case unknown
    case inactive
}

struct Slot: Sendable, Hashable, Codable, Equatable {
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

struct CalendarMonthRange: Sendable, Hashable, Codable, Equatable {
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

enum DayOfMonthEnd: Sendable, Hashable, Equatable {
    case day(Int)
    case last
}

struct CalendarDayOfMonthRange: Sendable, Hashable, Equatable {
    var start: Int
    var end: DayOfMonthEnd

    nonisolated init(start: Int, end: DayOfMonthEnd) {
        self.start = start
        self.end = end
    }
}

struct ScheduleCalendar: Sendable, Hashable, Equatable {
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

struct TimeWindow: Sendable, Hashable, Equatable {
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

struct ScheduleFlags: Sendable, Hashable, Codable, Equatable {
    var exceptPublicHolidays: Bool?

    nonisolated init(exceptPublicHolidays: Bool? = nil) {
        self.exceptPublicHolidays = exceptPublicHolidays
    }

    enum CodingKeys: String, CodingKey {
        case exceptPublicHolidays
    }
}

struct Schedule: Sendable, Hashable, Equatable {
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

struct SlotEvaluation: Sendable, Equatable {
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
