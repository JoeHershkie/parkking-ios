import Testing
@testable import Parkking

@Suite("Verdict sheet")
struct VerdictSheetTests {
    private func makeRule(
        id: Int,
        category: String,
        rule: String,
        sourceID: String? = nil,
        max: String? = nil,
        maxMinutes: Int? = nil,
        kind: ContributingRuleKind = .inactive,
        reason: String = ""
    ) -> ContributingRule {
        let feature = ParkingFeature(
            id: FeatureID(id),
            geometry: .lineString(coordinates: [[-79.4, 43.65], [-79.401, 43.65]]),
            properties: ParkingProperties(
                highway: "Bainbridge Ave",
                rule: rule,
                scheduleCategory: category,
                side: "North",
                max: max,
                schedule: nil,
                maxMinutes: maxMinutes,
                sourceID: sourceID ?? "\(id)"
            )
        )
        return ContributingRule(
            feature: feature,
            evaluation: SlotEvaluation(visible: true, polarity: .restricted, unparsed: false),
            kind: kind,
            reason: reason.isEmpty ? rule : reason
        )
    }

    @Test("deduplicates rules with identical formatted text from different feature IDs")
    func deduplicatesIdenticalRulesWithDifferentIDs() {
        let rule1 = makeRule(
            id: 101,
            category: "no_parking",
            rule: "7:00 a.m. to 6:00 p.m., Mon. to Fri.",
            sourceID: "src-101"
        )
        let rule2 = makeRule(
            id: 102,
            category: "no_parking",
            rule: "7:00 a.m. to 6:00 p.m., Mon. to Fri.",
            sourceID: "src-102"
        )
        let rule3 = makeRule(
            id: 103,
            category: "no_stopping",
            rule: "7:00 a.m. to 9:00 a.m., Mon. to Fri.",
            sourceID: "src-103"
        )

        let deduped = VerdictSheet.dedupedRules([rule1, rule2, rule3])
        #expect(deduped.count == 2)
        #expect(deduped[0].feature.id.rawValue == "101")
        #expect(deduped[1].feature.id.rawValue == "103")

        let formatted = deduped.map { VerdictSheet.formatAppliedRule($0) }
        #expect(formatted == [
            "No parking: \"7:00 a.m. to 6:00 p.m., Mon. to Fri.\"",
            "No stopping: \"7:00 a.m. to 9:00 a.m., Mon. to Fri.\"",
        ])
    }

    @Test("formats restricted periods with duration")
    func formatsRestrictedPeriods() {
        let rule = makeRule(
            id: 201,
            category: "restricted_periods",
            rule: "8:00 a.m. to 6:00 p.m., Mon. to Sat.",
            max: "2 hours",
            maxMinutes: 120
        )
        let formatted = VerdictSheet.formatAppliedRule(rule)
        #expect(formatted == "Allowed periods: 2 hr, \"8:00 a.m. to 6:00 p.m., Mon. to Sat.\"")
    }

    @Test("rulesToDisplay prefers activeRestrictions and deduplicates them")
    func rulesToDisplayDeduplicatesActiveRestrictions() {
        let active1 = makeRule(
            id: 301,
            category: "no_parking",
            rule: "8:00 a.m. to 6:00 p.m.",
            sourceID: "src-301",
            kind: .noParking
        )
        let active2 = makeRule(
            id: 302,
            category: "no_parking",
            rule: "8:00 a.m. to 6:00 p.m.",
            sourceID: "src-302",
            kind: .noParking
        )

        let verdict = CurbVerdict(
            status: .notAllowed,
            headline: "Not allowed",
            primaryReason: "No parking",
            contributingRules: [active1, active2],
            activeRestrictions: [active1, active2],
            uncertaintyNotes: [],
            maxStayWarning: nil,
            midnightWarning: nil,
            signageReminder: "Check signs",
            street: "Bainbridge Ave",
            side: "North",
            sideDisplay: "North side"
        )

        let displayed = VerdictSheet.rulesToDisplay(verdict)
        #expect(displayed.count == 1)
        #expect(VerdictSheet.formatAppliedRule(displayed[0]) == "No parking: \"8:00 a.m. to 6:00 p.m.\"")
    }
}
