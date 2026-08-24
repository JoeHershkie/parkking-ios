import MapKit
import SwiftUI

struct ParkingMapScreen: View {
    @State private var viewModel = ParkingMapViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var sheetDetent: PresentationDetent = .height(180)

    var body: some View {
        ParkingMapKitView(viewModel: viewModel)
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                MapFloatingChrome(viewModel: viewModel)
            }
            .sheet(isPresented: .constant(true)) {
                VerdictSheet(viewModel: viewModel, detent: $sheetDetent)
                    .presentationDetents([.height(180), .medium, .large], selection: $sheetDetent)
                    .presentationDragIndicator(.visible)
                    .presentationBackgroundInteraction(.enabled(upThrough: .height(180)))
                    .interactiveDismissDisabled()
            }
            .onAppear { viewModel.onAppear() }
            .onDisappear { viewModel.onDisappear() }
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
                if size.isAccessibilitySize, sheetDetent == .height(180) {
                    sheetDetent = .medium
                }
            }
    }
}

#Preview {
    ParkingMapScreen()
}
