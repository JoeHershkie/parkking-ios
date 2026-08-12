import MapKit
import SwiftUI

struct ParkingMapScreen: View {
    @State private var viewModel = ParkingMapViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var sheetDetent: PresentationDetent = .height(220)

    var body: some View {
        MapReader { proxy in
            Map(position: $viewModel.cameraPosition, bounds: ParkingMapConstants.torontoBounds) {
                ForEach(viewModel.renderItems) { item in
                    MapPolyline(coordinates: item.coordinates)
                        .stroke(
                            strokeColor(for: item),
                            style: StrokeStyle(
                                lineWidth: item.isSelected ? 8 : (item.severity == 2 ? 5 : 3),
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                }
            }
            .mapStyle(
                .standard(
                    elevation: .flat,
                    pointsOfInterest: .excludingAll,
                    showsTraffic: false
                )
            )
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                viewModel.handleCameraChange(context)
            }
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        if let coordinate = proxy.convert(value.location, from: .local) {
                            viewModel.handleTap(at: coordinate)
                        }
                    }
            )
            .ignoresSafeArea()
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

    private func strokeColor(for item: ParkingMapRenderItem) -> Color {
        if item.isSelected {
            return Color.primary.opacity(0.85)
        }
        switch item.polarity {
        case .restricted, .notPermitted:
            return Color.red
        case .unknown:
            return Color.orange
        case .permitted, .inactive:
            return Color.green
        }
    }
}

#Preview {
    ParkingMapScreen()
}
