import SwiftUI

struct MapFloatingChrome: View {
    @Bindable var viewModel: ParkingMapViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                locationButton
                timeButton
                gpsButton
            }

            if let error = viewModel.locationError {
                LocationPermissionBanner(
                    message: error.bannerMessage,
                    showsSettings: error.canOpenSettings,
                    onOpenSettings: { viewModel.openSettings() }
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private var locationButton: some View {
        Button {
            viewModel.presentedModal = .location
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "mappin")
                    .font(.body.weight(.semibold))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Location")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(viewModel.locationLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.horizontal, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.isDataReady)
        .accessibilityLabel("Location")
        .accessibilityValue(viewModel.locationLabel)
        .accessibilityHint("Search for a Toronto address")
    }

    private var timeButton: some View {
        Button {
            viewModel.presentedModal = .time
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.body.weight(.semibold))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Time")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(viewModel.timeChip)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
            }
            .frame(minHeight: 44)
            .padding(.horizontal, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.isDataReady)
        .accessibilityLabel("Time")
        .accessibilityValue(viewModel.timeChip)
        .accessibilityHint("Change check time and duration")
    }

    private var gpsButton: some View {
        Button {
            viewModel.tapLocate()
        } label: {
            Group {
                if viewModel.isLocating {
                    ProgressView()
                } else {
                    Image(systemName: "location.fill")
                        .font(.body.weight(.semibold))
                }
            }
            .frame(width: 44, height: 44)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.isDataReady || viewModel.isLocating)
        .accessibilityLabel("Use my location")
        .accessibilityValue(gpsAccessibilityValue)
        .accessibilityHint("Find parking near your current location")
    }

    private var gpsAccessibilityValue: String {
        if viewModel.isLocating { return "Locating" }
        if viewModel.isLocationAuthorized { return "Authorized" }
        return "Not authorized"
    }
}

struct LocationPermissionBanner: View {
    var message: String
    var showsSettings: Bool
    var onOpenSettings: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(message)
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            if showsSettings {
                Button("Open Settings", action: onOpenSettings)
                    .font(.footnote.weight(.bold))
                    .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
