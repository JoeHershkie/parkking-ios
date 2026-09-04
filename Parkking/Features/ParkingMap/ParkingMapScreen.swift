import MapKit
import SwiftUI

struct ParkingMapScreen: View {
    var isSplashActive: Bool = false
    @State private var viewModel = ParkingMapViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var sheetDetent: PresentationDetent = .height(76)

    private func calculateBottomInset(in containerHeight: CGFloat) -> CGFloat {
        if viewModel.isResultPresented {
            switch sheetDetent {
            case VerdictSheet.compactDetent, .height(76):
                return 228
            case .medium:
                return containerHeight * 0.55 + 16
            case .large:
                return containerHeight * 0.90 + 16
            default:
                return 228
            }
        } else {
            switch sheetDetent {
            case .height(76), VerdictSheet.compactDetent:
                return 88
            case .medium:
                return containerHeight * 0.55 + 16
            case .large:
                return containerHeight * 0.90 + 16
            default:
                return 88
            }
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let bottomInset = calculateBottomInset(in: proxy.size.height)
            ParkingMapKitView(viewModel: viewModel, bottomPadding: bottomInset)
                .ignoresSafeArea()
                .overlay {
                    MapFloatingChrome(viewModel: viewModel, bottomPadding: bottomInset)
                }
        }
        .sheet(isPresented: Binding(
            get: { !isSplashActive },
            set: { _ in }
        )) {
            Group {
                if viewModel.isResultPresented {
                    VerdictSheet(viewModel: viewModel, detent: $sheetDetent)
                } else {
                    SearchSheet(viewModel: viewModel, detent: $sheetDetent)
                }
            }
            .presentationDetents(
                viewModel.isResultPresented
                    ? [VerdictSheet.compactDetent, .medium, .large]
                    : [.height(76), .medium, .large],
                selection: $sheetDetent
            )
            .presentationDragIndicator(.hidden)
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            .interactiveDismissDisabled()
        }
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        .onChange(of: viewModel.isResultPresented) { wasPresented, isPresented in
            if isPresented && !wasPresented {
                sheetDetent = dynamicTypeSize.isAccessibilitySize ? .medium : VerdictSheet.compactDetent
            } else if !isPresented && wasPresented {
                sheetDetent = dynamicTypeSize.isAccessibilitySize ? .medium : .height(76)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                viewModel.sceneBecameActive()
            case .inactive, .background:
                viewModel.sceneBecameInactive()
            @unknown default:
                break
            }
        }
        .onChange(of: dynamicTypeSize) { _, size in
            if size.isAccessibilitySize {
                sheetDetent = .medium
            }
        }
    }
}

#Preview {
    ParkingMapScreen()
}
