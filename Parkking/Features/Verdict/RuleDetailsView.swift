import SwiftUI

struct RuleDetailsView: View {
    var rules: [ContributingRule]
    @State private var copyController = BylawCopyController()

    var body: some View {
        if rules.isEmpty {
            Text("No mapped curb rules at this point.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(rules.enumerated()), id: \.offset) { _, rule in
                    ruleCard(rule)
                }
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func ruleCard(_ rule: ContributingRule) -> some View {
        let props = rule.feature.properties
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(ParkingLabels.scheduleCategoryLabel(props.scheduleCategory))
                    .font(.footnote.weight(.bold))
                Spacer()
                Text(rule.kind.rawValue.replacingOccurrences(of: "_", with: " "))
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("Side")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(props.side)
                        .font(.caption.weight(.semibold))
                }
                if let max = ParkingLabels.formatMaxStay(max: props.max, maxMinutes: props.maxMinutes) {
                    VStack(alignment: .leading) {
                        Text("Max stay")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text(max)
                            .font(.caption.weight(.semibold))
                    }
                }
            }

            // Pipeline Data Badges (Permit Area, Hydrant, Snow Route, Streetcar)
            if props.permitAreaID != nil || props.hasHydrant == true || props.isSnowRoute == true || props.streetcarCorridor == true {
                FlowLayout(spacing: 6) {
                    if let permitID = props.permitAreaID {
                        Label("Permit Area \(permitID)", systemImage: "parkingsign.circle.fill")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.purple.opacity(0.15), in: Capsule())
                            .foregroundStyle(Color.purple)
                    }

                    if props.hasHydrant == true {
                        Label("3m Hydrant Setback", systemImage: "flame.fill")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.red.opacity(0.15), in: Capsule())
                            .foregroundStyle(Color.red)
                    }

                    if props.isSnowRoute == true {
                        Label("Snow Route", systemImage: "snowflake")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.15), in: Capsule())
                            .foregroundStyle(Color.blue)
                    }

                    if props.streetcarCorridor == true {
                        Label("Streetcar Corridor", systemImage: "tram.fill")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.15), in: Capsule())
                            .foregroundStyle(Color.orange)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Bylaw text")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    let copyKey = rule.feature.ruleKey.rawValue
                    Button {
                        copyController.copy(props.rule, key: copyKey)
                    } label: {
                        Label(
                            copyController.title(for: copyKey),
                            systemImage: copyController.copiedKey == copyKey
                                ? "checkmark"
                                : "doc.on.doc"
                        )
                        .font(.caption.weight(.bold))
                    }
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                    .accessibilityLabel(copyController.title(for: copyKey))
                    .accessibilityValue(
                        copyController.copiedKey == copyKey ? "Copied to clipboard" : "Copy bylaw text"
                    )
                }
                Text("“\(props.rule)”")
                    .font(.caption.italic())
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background, in: RoundedRectangle(cornerRadius: 8))
            }

            if let regionalRule = props.regionalWinterRule {
                Text("\(props.formerMunicipality ?? "Regional") Winter Rule: \(regionalRule)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.indigo)
            }

            ForEach(
                Array(ScheduleDisplay.scheduleStatusHints(props.schedule).enumerated()),
                id: \.offset
            ) { _, hint in
                Text(hint.text)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }

            if props.schedule?.flags?.exceptPublicHolidays == true {
                Text("Exempt on public holidays.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.teal)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
    }
}

/// Simple flowing horizontal tag layout
private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return CGSize(width: width, height: currentY + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
