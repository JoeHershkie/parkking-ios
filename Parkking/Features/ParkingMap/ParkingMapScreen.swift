import MapKit
import SwiftUI

struct ParkingMapScreen: View {
    @State private var viewModel = ParkingMapViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var searchDetent: PresentationDetent = .height(76)
    @State private var resultDetent: PresentationDetent = VerdictSheet.compactDetent

    private func calculateBottomInset(in containerHeight: CGFloat) -> CGFloat {
        if viewModel.isResultPresented {
            switch resultDetent {
            case VerdictSheet.compactDetent:
                return 192
            case .medium:
                return containerHeight * 0.55 + 16
            case .large:
                return containerHeight * 0.90 + 16
            default:
                return 192
            }
        } else {
            switch searchDetent {
            case .height(76):
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
            .sheet(isPresented: .constant(true)) {
                SearchSheet(viewModel: viewModel, detent: $searchDetent)
                    .presentationDetents([.height(76), .medium, .large], selection: $searchDetent)
                    .presentationDragIndicator(.visible)
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                    .interactiveDismissDisabled()
                    .sheet(isPresented: $viewModel.isResultPresented) {
                        VerdictSheet(viewModel: viewModel, detent: $resultDetent)
                            .presentationDetents([VerdictSheet.compactDetent, .medium, .large], selection: $resultDetent)
                            .presentationDragIndicator(.visible)
                            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                            .interactiveDismissDisabled(false)
                    }
            }
            .onAppear { viewModel.onAppear() }
            .onDisappear { viewModel.onDisappear() }
            .onChange(of: viewModel.isResultPresented) { wasPresented, isPresented in
                if isPresented && !wasPresented {
                    resultDetent = VerdictSheet.compactDetent
                } else if !isPresented && wasPresented {
                    viewModel.dismissResult()
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
                    if searchDetent == .height(76) {
                        searchDetent = .medium
                    }
                    if resultDetent == VerdictSheet.compactDetent {
                        resultDetent = .medium
                    }
                }
            }
    }
}

#Preview {
    ParkingMapScreen()
}
