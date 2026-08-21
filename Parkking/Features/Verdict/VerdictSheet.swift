import SwiftUI

struct VerdictSheet: View {
    @Bindable var viewModel: ParkingMapViewModel
    @Binding var detent: PresentationDetent
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch viewModel.sheetPrompt {
                    case .loading:
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Loading curb rules…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                        .accessibilityElement(children: .combine)

                    case .failed(let message):
                        ContentUnavailableView(
                            "Couldn’t load map data",
                            systemImage: "exclamationmark.triangle",
                            description: Text(message)
                        )
                        Button("Retry") { viewModel.retry() }
                            .buttonStyle(.borderedProminent)
                            .frame(minHeight: 44)

                    case .zoomIn:
                        Label(
                            viewModel.sheetPrompt.coachingText
                                ?? "Zoom in to see parking availability",
                            systemImage: "plus.magnifyingglass"
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    case .tapPrompt:
                        Label(
                            viewModel.sheetPrompt.coachingText ?? "Tap to find parking",
                            systemImage: "hand.tap"
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    case .verdict:
                        if let verdict = viewModel.verdict {
                            compactVerdict(verdict)
                            if viewModel.sheetExpanded
                                || detent != .height(180)
                                || dynamicTypeSize.isAccessibilitySize
                            {
                                expandedContent(verdict)
                            } else {
                                Button {
                                    viewModel.sheetExpanded = true
                                    detent = .medium
                                } label: {
                                    Label("Show rule details", systemImage: "chevron.up")
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
                .padding()
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(item: $viewModel.presentedModal) { modal in
            switch modal {
            case .location:
                LocationSheet(viewModel: viewModel)
            case .time:
                TimeSheet(query: viewModel.appliedTimeQuery) { query in
                    viewModel.applyTimeQuery(query)
                }
            }
        }
        .onChange(of: viewModel.presentedModal) { _, modal in
            if modal == nil {
                detent = .height(180)
            }
        }
        .onAppear {
            if dynamicTypeSize.isAccessibilitySize, detent == .height(180) {
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
                if let side = verdict.sideDisplay {
                    Text(side)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Side: \(side)")
                }
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
        }
        .accessibilityElement(children: .combine)

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
    private func expandedContent(_ verdict: CurbVerdict) -> some View {
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

        DisclosureGroup(
            "Rule details (\(verdict.contributingRules.count))",
            isExpanded: $viewModel.sheetExpanded
        ) {
            RuleDetailsView(rules: dedupedRules(verdict.contributingRules))
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
        detent: .constant(.height(180))
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
        reason: String
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
