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
