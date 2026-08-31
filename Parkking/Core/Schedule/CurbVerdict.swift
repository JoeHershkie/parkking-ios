import Foundation

enum CurbVerdictStatus: String, Sendable, Equatable {
    case parkingAllowed = "parking_allowed"
    case notAllowed = "not_allowed"
    case likelyAllowed = "likely_allowed"
    case scheduleUnclear = "schedule_unclear"
}

enum RestrictionKind: String, Sendable, Equatable {
    case noStopping = "no_stopping"
    case noStanding = "no_standing"
    case noParking = "no_parking"
    case permittedWindow = "permitted_window"
    case maxStay = "max_stay"
    case uncertain
}

enum ContributingRuleKind: String, Sendable, Equatable {
    case noStopping = "no_stopping"
    case noStanding = "no_standing"
    case noParking = "no_parking"
    case permittedWindow = "permitted_window"
    case maxStay = "max_stay"
    case uncertain
    case inactive
    case allowed
}

struct ContributingRule: Sendable, Equatable {
    var feature: ParkingFeature
    var evaluation: SlotEvaluation
    var kind: ContributingRuleKind
    var reason: String

    nonisolated init(
        feature: ParkingFeature,
        evaluation: SlotEvaluation,
        kind: ContributingRuleKind,
        reason: String
    ) {
        self.feature = feature
        self.evaluation = evaluation
        self.kind = kind
        self.reason = reason
    }
}

struct CurbVerdict: Sendable, Equatable {
    var status: CurbVerdictStatus
    var headline: String
    var primaryReason: String?
    var contributingRules: [ContributingRule]
    var activeRestrictions: [ContributingRule]
    var uncertaintyNotes: [String]
    var maxStayWarning: String?
    var midnightWarning: String?
    var signageReminder: String
    var street: String?
    var side: String?
    var sideDisplay: String?

    nonisolated init(
        status: CurbVerdictStatus,
        headline: String,
        primaryReason: String?,
        contributingRules: [ContributingRule],
        activeRestrictions: [ContributingRule],
        uncertaintyNotes: [String],
        maxStayWarning: String?,
        midnightWarning: String?,
        signageReminder: String,
        street: String?,
        side: String?,
        sideDisplay: String?
    ) {
        self.status = status
        self.headline = headline
        self.primaryReason = primaryReason
        self.contributingRules = contributingRules
        self.activeRestrictions = activeRestrictions
        self.uncertaintyNotes = uncertaintyNotes
        self.maxStayWarning = maxStayWarning
        self.midnightWarning = midnightWarning
        self.signageReminder = signageReminder
        self.street = street
        self.side = side
        self.sideDisplay = sideDisplay
    }
}

struct ComposeCurbVerdictOptions: Sendable {
    var features: [ParkingFeature]
    var slot: Slot
    var effectiveEndMinute: Int?
    var requestedDurationMinutes: Int
    var truncatedAtMidnight: Bool
    var includeUnknown: Bool
    var street: String?
    var side: String?
    var sideDisplay: String?

    nonisolated init(
        features: [ParkingFeature],
        slot: Slot,
        effectiveEndMinute: Int?,
        requestedDurationMinutes: Int,
        truncatedAtMidnight: Bool = false,
        includeUnknown: Bool = true,
        street: String? = nil,
        side: String? = nil,
        sideDisplay: String? = nil
    ) {
        self.features = features
        self.slot = slot
        self.effectiveEndMinute = effectiveEndMinute
        self.requestedDurationMinutes = requestedDurationMinutes
        self.truncatedAtMidnight = truncatedAtMidnight
        self.includeUnknown = includeUnknown
        self.street = street
        self.side = side
        self.sideDisplay = sideDisplay
    }
}

enum CurbVerdictComposer {
    nonisolated private static let signageReminder = "Check posted signs."

    nonisolated private static let restrictionPrecedence: [ContributingRuleKind: Int] = [
        .noStopping: 0,
        .noStanding: 1,
        .noParking: 2,
        .permittedWindow: 3,
        .maxStay: 4,
        .uncertain: 5,
    ]

    nonisolated private static let headlines: [CurbVerdictStatus: String] = [
        .parkingAllowed: "Parking allowed",
        .notAllowed: "Not allowed",
        .likelyAllowed: "Likely allowed",
        .scheduleUnclear: "Schedule unclear",
    ]

    nonisolated private static func categoryKind(_ category: String) -> RestrictionKind? {
        switch category {
        case "no_stopping": return .noStopping
        case "no_standing": return .noStanding
        case "no_parking": return .noParking
        case "restricted_periods": return .permittedWindow
        default: return nil
        }
    }

    nonisolated private static func reasonForRestriction(
        kind: RestrictionKind,
        props: ParkingProperties,
        polarity: FilterPolarity
    ) -> String {
        switch kind {
        case .noStopping:
            return "No stopping"
        case .noStanding:
            return "No standing"
        case .noParking:
            return "No parking"
        case .permittedWindow:
            return polarity == .notPermitted
                ? "Outside the permitted parking window."
                : "Permitted-window rule applies."
        case .maxStay:
            if let max = ParkingLabels.formatMaxStay(max: props.max, maxMinutes: props.maxMinutes) {
                return "Requested stay exceeds max stay of \(max)."
            }
            return "Requested stay exceeds the posted max stay."
        case .uncertain:
            return "Schedule data is incomplete for this rule."
        }
    }

    nonisolated private static func maxStayViolated(
        props: ParkingProperties,
        requestedDurationMinutes: Int
    ) -> Bool {
        if requestedDurationMinutes <= 0 { return false }
        if let maxMinutes = props.maxMinutes, maxMinutes > 0 {
            return requestedDurationMinutes > maxMinutes
        }
        return false
    }

    nonisolated private static func classifyRule(
        feature: ParkingFeature,
        evaluation: SlotEvaluation,
        requestedDurationMinutes: Int
    ) -> ContributingRule {
        let props = feature.properties
        let polarity = evaluation.polarity

        if evaluation.failed == true || evaluation.unparsed || polarity == .unknown {
            return ContributingRule(
                feature: feature,
                evaluation: evaluation,
                kind: .uncertain,
                reason: reasonForRestriction(kind: .uncertain, props: props, polarity: polarity)
            )
        }

        if polarity == .restricted {
            let kind = categoryKind(props.scheduleCategory) ?? .noParking
            let ruleKind: ContributingRuleKind
            switch kind {
            case .noStopping: ruleKind = .noStopping
            case .noStanding: ruleKind = .noStanding
            case .noParking: ruleKind = .noParking
            case .permittedWindow: ruleKind = .permittedWindow
            case .maxStay: ruleKind = .maxStay
            case .uncertain: ruleKind = .uncertain
            }
            return ContributingRule(
                feature: feature,
                evaluation: evaluation,
                kind: ruleKind,
                reason: reasonForRestriction(kind: kind, props: props, polarity: polarity)
            )
        }

        if polarity == .notPermitted {
            return ContributingRule(
                feature: feature,
                evaluation: evaluation,
                kind: .permittedWindow,
                reason: reasonForRestriction(
                    kind: .permittedWindow,
                    props: props,
                    polarity: polarity
                )
            )
        }

        if (polarity == .permitted || polarity == .inactive)
            && maxStayViolated(props: props, requestedDurationMinutes: requestedDurationMinutes)
        {
            return ContributingRule(
                feature: feature,
                evaluation: evaluation,
                kind: .maxStay,
                reason: reasonForRestriction(kind: .maxStay, props: props, polarity: polarity)
            )
        }

        if polarity == .permitted {
            return ContributingRule(
                feature: feature,
                evaluation: evaluation,
                kind: .allowed,
                reason: "Parking is permitted under this rule."
            )
        }

        return ContributingRule(
            feature: feature,
            evaluation: evaluation,
            kind: .inactive,
            reason: "Restriction is not active for this interval."
        )
    }

    nonisolated private static func pickPrimary(
        _ restrictions: [ContributingRule]
    ) -> ContributingRule? {
        guard !restrictions.isEmpty else { return nil }
        return restrictions.sorted { a, b in
            let ak = restrictionPrecedence[a.kind] ?? 99
            let bk = restrictionPrecedence[b.kind] ?? 99
            return ak < bk
        }.first
    }

    /// Convenience overload matching web `composeCurbVerdict({ ... })` call sites.
    nonisolated static func composeCurbVerdict(
        features: [ParkingFeature],
        slot: Slot,
        effectiveEndMinute: Int?,
        requestedDurationMinutes: Int,
        truncatedAtMidnight: Bool = false,
        includeUnknown: Bool = true,
        street: String? = nil,
        side: String? = nil,
        sideDisplay: String? = nil
    ) -> CurbVerdict {
        composeCurbVerdict(
            ComposeCurbVerdictOptions(
                features: features,
                slot: slot,
                effectiveEndMinute: effectiveEndMinute,
                requestedDurationMinutes: requestedDurationMinutes,
                truncatedAtMidnight: truncatedAtMidnight,
                includeUnknown: includeUnknown,
                street: street,
                side: side,
                sideDisplay: sideDisplay
            )
        )
    }

    /// Compose all local overlapping rules for one curb side into a single verdict.
    /// Known restrictions override uncertainty. Precedence:
    /// no stopping → no standing → no parking → permitted-window → max-stay.
    nonisolated static func composeCurbVerdict(
        _ options: ComposeCurbVerdictOptions
    ) -> CurbVerdict {
        let midnightWarning =
            options.truncatedAtMidnight ? ParkingTimeQuery.midnightWarning : nil

        if options.features.isEmpty {
            return CurbVerdict(
                status: .likelyAllowed,
                headline: headlines[.likelyAllowed]!,
                primaryReason: "No mapped restriction found; data may be incomplete.",
                contributingRules: [],
                activeRestrictions: [],
                uncertaintyNotes: [
                    "No mapped restriction found; data may be incomplete.",
                ],
                maxStayWarning: nil,
                midnightWarning: midnightWarning,
                signageReminder: signageReminder,
                street: options.street,
                side: options.side,
                sideDisplay: options.sideDisplay
            )
        }

        let contributingRules = options.features.map { feature in
            let evaluation = ScheduleEvaluator.evaluateInRange(
                props: feature.properties,
                slot: options.slot,
                endMinuteOfDay: options.effectiveEndMinute,
                includeUnknown: options.includeUnknown
            )
            return classifyRule(
                feature: feature,
                evaluation: evaluation,
                requestedDurationMinutes: options.requestedDurationMinutes
            )
        }

        let hasActivePermit = contributingRules.contains { $0.kind == .allowed }
        let normalizedRules: [ContributingRule]
        if hasActivePermit {
            normalizedRules = contributingRules.map { rule in
                if rule.kind == .permittedWindow {
                    var updated = rule
                    updated.kind = .inactive
                    updated.reason = "Another posted rule covers this interval."
                    return updated
                }
                return rule
            }
        } else {
            normalizedRules = contributingRules
        }

        let hardKinds: Set<ContributingRuleKind> = [
            .noStopping, .noStanding, .noParking, .permittedWindow, .maxStay,
        ]
        let hardRestrictions = normalizedRules.filter { hardKinds.contains($0.kind) }
        let uncertainRules = normalizedRules.filter { $0.kind == .uncertain }

        var uncertaintyNotes: [String] = []
        for rule in uncertainRules {
            let hints = ScheduleDisplay.scheduleStatusHints(rule.feature.properties.schedule)
            if !hints.isEmpty {
                for hint in hints {
                    uncertaintyNotes.append(hint.text)
                }
            } else if rule.feature.properties.schedule == nil {
                uncertaintyNotes.append("No schedule data for a mapped rule.")
            } else {
                uncertaintyNotes.append(rule.reason)
            }
        }

        let maxStayRule = hardRestrictions.first { $0.kind == .maxStay }
        let maxStayWarning = maxStayRule?.reason

        // Known restrictions override uncertainty.
        if !hardRestrictions.isEmpty {
            let primary = pickPrimary(hardRestrictions)!
            return CurbVerdict(
                status: .notAllowed,
                headline: headlines[.notAllowed]!,
                primaryReason: primary.reason,
                contributingRules: normalizedRules,
                activeRestrictions: hardRestrictions,
                uncertaintyNotes: uniquePreserveOrder(uncertaintyNotes),
                maxStayWarning: maxStayWarning,
                midnightWarning: midnightWarning,
                signageReminder: signageReminder,
                street: options.street,
                side: options.side,
                sideDisplay: options.sideDisplay
            )
        }

        if !uncertainRules.isEmpty {
            return CurbVerdict(
                status: .scheduleUnclear,
                headline: headlines[.scheduleUnclear]!,
                primaryReason: uncertaintyNotes.first
                    ?? "Missing or incomplete schedule data prevents a reliable answer.",
                contributingRules: normalizedRules,
                activeRestrictions: [],
                uncertaintyNotes: uniquePreserveOrder(uncertaintyNotes),
                maxStayWarning: nil,
                midnightWarning: midnightWarning,
                signageReminder: signageReminder,
                street: options.street,
                side: options.side,
                sideDisplay: options.sideDisplay
            )
        }

        return CurbVerdict(
            status: .parkingAllowed,
            headline: headlines[.parkingAllowed]!,
            primaryReason: "Mapped rules permit this interval.",
            contributingRules: normalizedRules,
            activeRestrictions: [],
            uncertaintyNotes: [],
            maxStayWarning: nil,
            midnightWarning: midnightWarning,
            signageReminder: signageReminder,
            street: options.street,
            side: options.side,
            sideDisplay: options.sideDisplay
        )
    }

    nonisolated static func composeCurbVerdictForQuery(
        features: [ParkingFeature],
        resolved: ResolvedTimeQuery,
        street: String? = nil,
        side: String? = nil,
        sideDisplay: String? = nil
    ) -> CurbVerdict {
        composeCurbVerdict(
            ComposeCurbVerdictOptions(
                features: features,
                slot: resolved.slot,
                effectiveEndMinute: resolved.effectiveEndMinute,
                requestedDurationMinutes: resolved.requestedDurationMinutes,
                truncatedAtMidnight: resolved.truncatedAtMidnight,
                street: street,
                side: side,
                sideDisplay: sideDisplay
            )
        )
    }

    nonisolated private static func uniquePreserveOrder(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values where seen.insert(value).inserted {
            result.append(value)
        }
        return result
    }
}
