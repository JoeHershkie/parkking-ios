import SwiftUI

struct MapFloatingChrome: View {
    @Bindable var viewModel: ParkingMapViewModel

    @State var isPressed = false
    var body: some View {
        VStack(spacing: 10) {
            coachingPromptPill
                .frame(maxWidth: .infinity, alignment: .center)

            if let error = viewModel.locationError {
                LocationPermissionBanner(
                    message: error.bannerMessage,
                    showsSettings: error.canOpenSettings,
                    onOpenSettings: { viewModel.openSettings() }
                )
            }

            Spacer()

            HStack {
                Spacer()
                gpsButton
            }
            .padding(.trailing, 16)
            .padding(.bottom, 90)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var coachingPromptPill: some View {
        if !viewModel.isResultPresented {
            switch viewModel.sheetPrompt {
            case .loading:
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Loading curb rules…")
                        .font(.subheadline.weight(.medium))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                .accessibilityElement(children: .combine)

            case .failed(let message):
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)
                    Text(message)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Button("Retry") {
                        viewModel.retry()
                    }
                    .font(.subheadline.weight(.bold))
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)

            case .zoomIn:
                if let text = viewModel.sheetPrompt.coachingText {
                    Label(text, systemImage: "plus.magnifyingglass")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                }

            case .tapPrompt:
                if let text = viewModel.sheetPrompt.coachingText {
                    Label(text, systemImage: "hand.tap")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                }

            case .idle, .verdict:
                EmptyView()
            }
        }
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
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(viewModel.isLocationAuthorized ? Color.accentColor : Color.primary)
                }
            }
            .frame(width: 48, height: 48)
            .background(.ultraThinMaterial, in: Circle())
            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
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
