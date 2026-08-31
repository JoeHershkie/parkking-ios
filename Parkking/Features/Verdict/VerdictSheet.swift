import SwiftUI

struct VerdictSheet: View {
    static let compactDetent = PresentationDetent.height(180)

    @Bindable var viewModel: ParkingMapViewModel
    @Binding var detent: PresentationDetent
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let verdict = viewModel.verdict {
                    compactVerdict(verdict)
                }
            }
            .padding()
        }
        .onAppear {
            if dynamicTypeSize.isAccessibilitySize, detent == VerdictSheet.compactDetent {
                detent = .medium
            }
        }
    }

    @ViewBuilder
    private func compactVerdict(_ verdict: CurbVerdict) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: statusSymbol(verdict.status))
                .font(.title2)
                .foregroundStyle(statusColor(verdict.status))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.cardAddress ?? verdict.street ?? "Selected location")
                    .font(.headline)
                    .lineLimit(2)
                Text(verdict.headline)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(statusColor(verdict.status))
                    .accessibilityLabel("Status: \(verdict.headline)")
                if let label = viewModel.resolvedQuery?.label {
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Interval: \(label)")
                }
            }

            Spacer(minLength: 0)

            Button {
                viewModel.dismissResult()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Color(uiColor: .tertiarySystemFill), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }

        let displayedRules = rulesToDisplay(verdict)
        if !displayedRules.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(displayedRules.enumerated()), id: \.offset) { _, rule in
                    Text(formatAppliedRule(rule))
                        .font(.footnote.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } else if let reason = verdict.primaryReason {
            Text(reason)
                .font(.footnote.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }

        if let warning = verdict.maxStayWarning {
            Label(warning, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.red)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                .fixedSize(horizontal: false, vertical: true)
        }

        if let warning = verdict.midnightWarning {
            Text(warning)
                .font(.footnote.weight(.semibold))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func rulesToDisplay(_ verdict: CurbVerdict) -> [ContributingRule] {
        if !verdict.activeRestrictions.isEmpty {
            return dedupedRules(verdict.activeRestrictions)
        } else if !verdict.contributingRules.isEmpty {
            return dedupedRules(verdict.contributingRules)
        } else {
            return []
        }
    }

    private func formatAppliedRule(_ rule: ContributingRule) -> String {
        let props = rule.feature.properties
        let label = ParkingLabels.scheduleCategoryLabel(props.scheduleCategory)
        let ruleText = props.rule.trimmingCharacters(in: .whitespacesAndNewlines)
        let duration = (props.scheduleCategory == "restricted_periods")
            ? ParkingLabels.formatAllowedPeriodDuration(max: props.max, maxMinutes: props.maxMinutes)
            : nil

        if let duration {
            if !ruleText.isEmpty {
                return "\(label): \(duration), \"\(ruleText)\""
            } else {
                return "\(label): \(duration)"
            }
        } else {
            if !ruleText.isEmpty {
                return "\(label): \"\(ruleText)\""
            } else {
                return label.isEmpty ? rule.reason : label
            }
        }
    }

    private func dedupedRules(_ rules: [ContributingRule]) -> [ContributingRule] {
        var seen = Set<String>()
        var out: [ContributingRule] = []
        for rule in rules {
            let key = ParkingLabels.ruleFeatureKey(rule.feature.properties)
            if seen.contains(key) { continue }
            seen.insert(key)
            out.append(rule)
        }
        return out
    }

    private func statusSymbol(_ status: CurbVerdictStatus) -> String {
        switch status {
        case .parkingAllowed: return "checkmark.circle.fill"
        case .likelyAllowed: return "questionmark.circle.fill"
        case .scheduleUnclear: return "exclamationmark.triangle.fill"
        case .notAllowed: return "xmark.circle.fill"
        }
    }

    private func statusColor(_ status: CurbVerdictStatus) -> Color {
        switch status {
        case .parkingAllowed: return .green
        case .likelyAllowed: return .teal
        case .scheduleUnclear: return .orange
        case .notAllowed: return .red
        }
    }
}

#if DEBUG
#Preview("Allowed") {
    VerdictSheet(
        viewModel: .preview(
            verdict: .preview(
                status: .parkingAllowed,
                headline: "Parking allowed",
                reason: "Mapped rules permit this interval."
            )
        ),
        detent: .constant(.medium)
    )
}

#Preview("Not allowed") {
    VerdictSheet(
        viewModel: .preview(
            verdict: .preview(
                status: .notAllowed,
                headline: "Not allowed",
                reason: "No stopping"
            )
        ),
        detent: .constant(.medium)
    )
}

#Preview("Unclear") {
    VerdictSheet(
        viewModel: .preview(
            verdict: .preview(
                status: .scheduleUnclear,
                headline: "Schedule unclear",
                reason: "Schedule data is incomplete for this rule."
            )
        ),
        detent: .constant(.medium)
    )
}

#Preview("Likely allowed") {
    VerdictSheet(
        viewModel: .preview(
            verdict: .preview(
                status: .likelyAllowed,
                headline: "Likely allowed",
                reason: "No mapped restriction found; data may be incomplete."
            )
        ),
        detent: .constant(VerdictSheet.compactDetent)
    )
}

private extension ParkingMapViewModel {
    static func preview(verdict: CurbVerdict) -> ParkingMapViewModel {
        let vm = ParkingMapViewModel(startsClock: false)
        vm.loadState = .loaded(featureCount: 1, lineFeatureCount: 1, skippedPoints: 0)
        vm.curbVisible = true
        vm.verdict = verdict
        vm.timeChip = "Now · 1h"
        vm.sheetExpanded = true
        return vm
    }
}

private extension CurbVerdict {
    static func preview(
        status: CurbVerdictStatus,
        headline: String,
        reason: String?
    ) -> CurbVerdict {
        CurbVerdict(
            status: status,
            headline: headline,
            primaryReason: reason,
            contributingRules: [],
            activeRestrictions: [],
            uncertaintyNotes: [],
            maxStayWarning: nil,
            midnightWarning: nil,
            signageReminder: "Check posted signs.",
            street: "Queen Street West",
            side: "North",
            sideDisplay: "North side"
        )
    }
}
#endif
