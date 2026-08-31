import SwiftUI

struct TimeMenuButton: View {
    enum Style {
        case searchCapsule
        case verdictChip(String)
    }

    @Bindable var viewModel: ParkingMapViewModel
    var style: Style = .searchCapsule
    @State private var isCustomSheetPresented = false

    var body: some View {
        Menu {
            Section("Quick Presets") {
                Button {
                    applyPreset(minutes: 30)
                } label: {
                    if isPresetActive(minutes: 30) {
                        Label("Now (30m)", systemImage: "checkmark")
                    } else {
                        Text("Now (30m)")
                    }
                }

                Button {
                    applyPreset(minutes: 60)
                } label: {
                    if isPresetActive(minutes: 60) {
                        Label("Now (1h)", systemImage: "checkmark")
                    } else {
                        Text("Now (1h)")
                    }
                }

                Button {
                    applyPreset(minutes: 120)
                } label: {
                    if isPresetActive(minutes: 120) {
                        Label("Now (2h)", systemImage: "checkmark")
                    } else {
                        Text("Now (2h)")
                    }
                }

                Button {
                    applyPreset(minutes: 180)
                } label: {
                    if isPresetActive(minutes: 180) {
                        Label("Now (3h)", systemImage: "checkmark")
                    } else {
                        Text("Now (3h)")
                    }
                }
            }

            Section {
                Button {
                    isCustomSheetPresented = true
                } label: {
                    if isCustomActive {
                        Label("Custom Date & Time…", systemImage: "checkmark")
                    } else {
                        Label("Custom Date & Time…", systemImage: "calendar")
                    }
                }
            }
        } label: {
            switch style {
            case .searchCapsule:
                searchCapsuleLabel
            case .verdictChip(let intervalLabel):
                verdictChipLabel(intervalLabel)
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isCustomSheetPresented) {
            TimeSheet(query: viewModel.appliedTimeQuery) { next in
                viewModel.applyTimeQuery(next)
            }
            .presentationDetents([.fraction(0.35), .medium])
            .presentationDragIndicator(.visible)
        }
    }

    private var searchCapsuleLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            Text(viewModel.timeChip)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(Color(uiColor: .tertiarySystemFill), in: Capsule(style: .continuous))
        .accessibilityLabel("Time filter: \(viewModel.timeChip)")
        .accessibilityHint("Select parking duration or choose custom date and time")
    }

    private func verdictChipLabel(_ intervalLabel: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(intervalLabel)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(uiColor: .tertiarySystemFill), in: Capsule(style: .continuous))
        .accessibilityLabel("Interval: \(intervalLabel)")
        .accessibilityHint("Tap to change duration or time")
    }

    private func isPresetActive(minutes: Int) -> Bool {
        viewModel.appliedTimeQuery.mode == .now
            && viewModel.appliedTimeQuery.requestedDurationMinutes == minutes
    }

    private var isCustomActive: Bool {
        viewModel.appliedTimeQuery.mode == .custom
            || !ParkingTimeQuery.durationPresets.contains(viewModel.appliedTimeQuery.requestedDurationMinutes)
    }

    private func applyPreset(minutes: Int) {
        let next = ParkingTimeQuery.createNowTimeQuery(
            durationMinutes: minutes,
            preset: .minutes(minutes)
        )
        viewModel.applyTimeQuery(next)
    }
}
