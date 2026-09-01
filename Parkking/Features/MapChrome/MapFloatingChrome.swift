import SwiftUI

struct MapFloatingChrome: View {
    @Bindable var viewModel: ParkingMapViewModel
    var bottomPadding: CGFloat = 88

    @State var isPressed = false
    var body: some View {
        VStack(spacing: 10) {
            coachingPromptPill
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 16)

            if let error = viewModel.locationError {
                LocationPermissionBanner(
                    message: error.bannerMessage,
                    showsSettings: error.canOpenSettings,
                    onOpenSettings: { viewModel.openSettings() }
                )
                .padding(.horizontal, 16)
            }

            Spacer()

            HStack {
                Spacer()
                rightControlsStack
                    .opacity(bottomPadding > 650 ? 0 : 1)
            }
            .padding(.trailing, 15)
            .padding(.bottom, bottomPadding)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: bottomPadding)
        }
        .padding(.top, 8)
    }

    private var rightControlsStack: some View {
        VStack(spacing: 8) {
            threeDButton
            connectedControlsPill
        }
    }

    private var threeDButton: some View {
        Button {
            viewModel.toggle3D()
        } label: {
            Text(viewModel.is3D ? "2D" : "3D")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.primary)
                .frame(width: 44, height: 44)
                .background(.regularMaterial, in: Circle())
                .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(viewModel.is3D ? "Switch to 2D view" : "Switch to 3D view")
    }

    private var connectedControlsPill: some View {
        VStack(spacing: 0) {
            mapStyleMenu
                .frame(width: 44, height: 44)

            Rectangle()
                .fill(Color(uiColor: .separator).opacity(0.35))
                .frame(width: 28, height: 0.5)

            gpsButton
                .frame(width: 44, height: 44)
        }
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
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
                .overlay(
                    Capsule()
                        .strokeBorder(Color(uiColor: .separator).opacity(0.35), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
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
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color(uiColor: .separator).opacity(0.35), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)

            case .zoomIn:
                if let text = viewModel.sheetPrompt.coachingText {
                    Label(text, systemImage: "plus.magnifyingglass")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(Color(uiColor: .separator).opacity(0.35), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                }

            case .tapPrompt:
                if let text = viewModel.sheetPrompt.coachingText {
                    Label(text, systemImage: "hand.tap")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(Color(uiColor: .separator).opacity(0.35), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                }

            case .idle, .verdict:
                EmptyView()
            }
        }
    }

    private var mapStyleMenu: some View {
        Menu {
            Picker("Map Style", selection: Binding(
                get: { viewModel.mapStyle },
                set: { viewModel.setMapStyle($0) }
            )) {
                ForEach(MapViewStyle.allCases) { style in
                    Label(style.title, systemImage: style.iconName)
                        .tag(style)
                }
            }
        } label: {
            Image(systemName: "map.fill")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Color.primary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Map style")
        .accessibilityValue(viewModel.mapStyle.title)
        .accessibilityHint("Change map style between Explore, Driving, Transit, and 3D Satellite")
    }

    private var gpsButton: some View {
        Button {
            viewModel.tapLocate()
        } label: {
            Group {
                if viewModel.isLocating {
                    ProgressView()
                } else {
                    Image(systemName: viewModel.isLocationCentered ? "location.fill" : "location")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Color(uiColor: .systemBlue))
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLocating)
        .accessibilityLabel("Use my location")
        .accessibilityValue(gpsAccessibilityValue)
        .accessibilityHint("Find parking near your current location")
    }

    private var gpsAccessibilityValue: String {
        if viewModel.isLocating { return "Locating" }
        if viewModel.isLocationCentered { return "Centered at current location" }
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
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(uiColor: .separator).opacity(0.35), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
        .accessibilityElement(children: .combine)
    }
}
