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

                    if detent != VerdictSheet.compactDetent || dynamicTypeSize.isAccessibilitySize {
                        nearbySidesSection
                    }

                    if detent == .large || dynamicTypeSize.isAccessibilitySize || viewModel.sheetExpanded {
                        ruleDetailsSection(verdict)
                    }
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
                Text(verdict.street ?? "Selected location")
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

        if let reason = verdict.primaryReason {
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

        Text(verdict.signageReminder)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var nearbySidesSection: some View {
        let rows = viewModel.nearbyStreetRows
        if rows.contains(where: { $0.sides.count > 0 }),
           (viewModel.selection?.groups.count ?? 0) > 1
        {
            VStack(alignment: .leading, spacing: 8) {
                Text("Nearby curb sides")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                ForEach(rows) { row in
                    HStack(spacing: 8) {
                        Text(row.street)
                            .font(.subheadline.weight(.bold))
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        HStack(spacing: 6) {
                            ForEach(row.sides) { chip in
                                sideChip(chip, street: row.street)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    @ViewBuilder
    private func ruleDetailsSection(_ verdict: CurbVerdict) -> some View {
        let rules = dedupedRules(verdict.contributingRules)
        VStack(alignment: .leading, spacing: 8) {
            Text("Rule details (\(rules.count))")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            RuleDetailsView(rules: rules)
        }
    }

    private func sideChip(_ chip: NearbySideChip, street: String) -> some View {
        let selected = viewModel.selection?.selectedGroupKey == chip.groupKey
        return Button {
            viewModel.selectGroup(chip.groupKey)
        } label: {
            Text(chip.letter)
                .font(.subheadline.weight(.black))
                .foregroundStyle(chip.tone.color)
                .frame(width: 44, height: 44)
                .background(chip.tone.color.opacity(0.16), in: RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(chip.tone.color.opacity(0.35), lineWidth: 1)
                }
                .overlay {
                    if selected {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.primary, lineWidth: 2)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(chip.accessibilityLabel(street: street))
        .accessibilityValue(chip.accessibilityValue)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
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
                reason: nil
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
                reason: "No parking is in effect for part of this interval."
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
