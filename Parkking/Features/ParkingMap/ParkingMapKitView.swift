import MapKit
import SwiftUI

struct ParkingMapKitView: UIViewRepresentable {
    @Bindable var viewModel: ParkingMapViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        map.isRotateEnabled = true
        map.isPitchEnabled = true
        map.isZoomEnabled = true
        map.isScrollEnabled = true
        map.showsCompass = false
        map.showsTraffic = false
        map.showsUserLocation = viewModel.isLocationAuthorized
        map.layoutMargins = UIEdgeInsets(
            top: ParkingMapConstants.chromeTopMargin,
            left: 0,
            bottom: ParkingMapConstants.chromeBottomMargin,
            right: 0
        )

        let config = MKStandardMapConfiguration()
        config.elevationStyle = .flat
        config.pointOfInterestFilter = .excludingAll
        config.showsTraffic = false
        map.preferredConfiguration = config

        map.cameraBoundary = MKMapView.CameraBoundary(
            coordinateRegion: ParkingMapConstants.parkingCoverageRegion
        )
        map.cameraZoomRange = MKMapView.CameraZoomRange(
            minCenterCoordinateDistance: ParkingMapConstants.minCameraDistance,
            maxCenterCoordinateDistance: ParkingMapConstants.maxCameraDistance
        )
        map.setRegion(ParkingMapConstants.cityRegion, animated: false)

        let compass = MKCompassButton(mapView: map)
        compass.compassVisibility = .adaptive
        compass.translatesAutoresizingMaskIntoConstraints = false
        map.addSubview(compass)
        NSLayoutConstraint.activate([
            compass.topAnchor.constraint(
                equalTo: map.safeAreaLayoutGuide.topAnchor,
                constant: ParkingMapConstants.chromeTopMargin
            ),
            compass.trailingAnchor.constraint(
                equalTo: map.safeAreaLayoutGuide.trailingAnchor,
                constant: -12
            ),
        ])

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tap.delegate = context.coordinator
        map.addGestureRecognizer(tap)

        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.viewModel = viewModel
        map.showsUserLocation = viewModel.isLocationAuthorized
        if let pending = viewModel.pendingCameraRegion {
            viewModel.pendingCameraRegion = nil
            map.setRegion(pending, animated: true)
        }
        context.coordinator.syncAnnotations(on: map)
        context.coordinator.syncOverlays(on: map)
    }

    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var viewModel: ParkingMapViewModel
        private var lastRenderItems: [ParkingMapRenderItem] = []
        private var lastSelectedIDs: Set<String> = []
        private var lastSearchPinID: String?
        private var lastTapDotID: String?
        private var colorOverlays: [ParkingOverlayBucketKind: ParkingStyledOverlay] = [:]
        private var selectedOverlays: [ParkingStyledOverlay] = []

        init(viewModel: ParkingMapViewModel) {
            self.viewModel = viewModel
        }

        func syncAnnotations(on map: MKMapView) {
            let currentPin = viewModel.searchPin
            let currentPinID = currentPin?.id

            let currentDot = viewModel.tapDot
            let currentDotID = currentDot?.id

            if currentPinID != lastSearchPinID {
                lastSearchPinID = currentPinID

                let existingSearchPins = map.annotations.compactMap { $0 as? SearchPinAnnotation }
                if !existingSearchPins.isEmpty {
                    map.removeAnnotations(existingSearchPins)
                }

                if let currentPin {
                    map.addAnnotation(currentPin)
                    map.selectAnnotation(currentPin, animated: true)
                }
            }

            if currentDotID != lastTapDotID {
                lastTapDotID = currentDotID

                let existingDots = map.annotations.compactMap { $0 as? TapDotAnnotation }
                if !existingDots.isEmpty {
                    map.removeAnnotations(existingDots)
                }

                if let currentDot {
                    map.addAnnotation(currentDot)
                }
            } else if let currentDot, let dotView = map.view(for: currentDot) as? TapDotAnnotationView {
                dotView.configure(with: currentDot)
            }
        }

        func syncOverlays(on map: MKMapView) {
            let items = viewModel.renderItems
            let selectedIDs = viewModel.selectedFeatureIDs
            let itemsChanged = items != lastRenderItems
            let selectionChanged = selectedIDs != lastSelectedIDs

            if !itemsChanged && !selectionChanged {
                return
            }

            let byID = Dictionary(
                items.map { ($0.id, $0) },
                uniquingKeysWith: { _, last in last }
            )
            let plan = ParkingOverlayStyling.plan(items: items, selectedFeatureIDs: selectedIDs)

            if itemsChanged {
                replaceColorOverlays(on: map, plan: plan, byID: byID)
                lastRenderItems = items
            }

            if itemsChanged || selectionChanged {
                replaceSelectedOverlays(on: map, plan: plan, byID: byID)
                lastSelectedIDs = selectedIDs
            }
        }

        private func replaceColorOverlays(
            on map: MKMapView,
            plan: ParkingOverlayStyling.Plan,
            byID: [ParkingMapRenderItem.ID: ParkingMapRenderItem]
        ) {
            map.removeOverlays(Array(colorOverlays.values))
            colorOverlays.removeAll(keepingCapacity: true)
            for kind in ParkingOverlayBucketKind.drawOrder {
                guard let ids = plan.colorBuckets[kind], !ids.isEmpty else { continue }
                let groupItems = ids.compactMap { byID[$0] }
                guard !groupItems.isEmpty else { continue }
                let overlay = ParkingStyledOverlay(kind: kind, role: .base, items: groupItems)
                colorOverlays[kind] = overlay
                map.addOverlay(overlay, level: .aboveRoads)
            }
        }

        private func replaceSelectedOverlays(
            on map: MKMapView,
            plan: ParkingOverlayStyling.Plan,
            byID: [ParkingMapRenderItem.ID: ParkingMapRenderItem]
        ) {
            if !selectedOverlays.isEmpty {
                map.removeOverlays(selectedOverlays)
                selectedOverlays.removeAll(keepingCapacity: true)
            }
            guard !plan.selectedIDs.isEmpty else { return }

            // 1. Add border overlays first (rendered under fill)
            for kind in ParkingOverlayBucketKind.drawOrder {
                guard let ids = plan.selectedBuckets[kind], !ids.isEmpty else { continue }
                let groupItems = ids.compactMap { byID[$0] }
                guard !groupItems.isEmpty else { continue }
                let overlay = ParkingStyledOverlay(kind: kind, role: .selectedBorder, items: groupItems)
                selectedOverlays.append(overlay)
                map.addOverlay(overlay, level: .aboveLabels)
            }

            // 2. Add fill overlays second (rendered on top of border with item's color at thickness 8)
            for kind in ParkingOverlayBucketKind.drawOrder {
                guard let ids = plan.selectedBuckets[kind], !ids.isEmpty else { continue }
                let groupItems = ids.compactMap { byID[$0] }
                guard !groupItems.isEmpty else { continue }
                let overlay = ParkingStyledOverlay(kind: kind, role: .selectedFill, items: groupItems)
                selectedOverlays.append(overlay)
                map.addOverlay(overlay, level: .aboveLabels)
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let pinAnnotation = annotation as? SearchPinAnnotation {
                let identifier = "SearchPinAnnotationView"
                let markerView: MKMarkerAnnotationView
                if let dequeued = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView {
                    markerView = dequeued
                    markerView.annotation = pinAnnotation
                } else {
                    markerView = MKMarkerAnnotationView(annotation: pinAnnotation, reuseIdentifier: identifier)
                }

                markerView.markerTintColor = .systemRed
                markerView.glyphTintColor = .white
                markerView.glyphImage = UIImage(systemName: "mappin")
                markerView.animatesWhenAdded = true
                markerView.canShowCallout = true
                markerView.displayPriority = .required
                markerView.titleVisibility = .adaptive
                markerView.subtitleVisibility = .adaptive

                return markerView
            }

            if let dotAnnotation = annotation as? TapDotAnnotation {
                let dotView: TapDotAnnotationView
                if let dequeued = mapView.dequeueReusableAnnotationView(withIdentifier: TapDotAnnotationView.reuseID) as? TapDotAnnotationView {
                    dotView = dequeued
                    dotView.annotation = dotAnnotation
                } else {
                    dotView = TapDotAnnotationView(annotation: dotAnnotation, reuseIdentifier: TapDotAnnotationView.reuseID)
                }
                dotView.configure(with: dotAnnotation)
                dotView.displayPriority = .required
                return dotView
            }

            return nil
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let styled = overlay as? ParkingStyledOverlay else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKMultiPolylineRenderer(multiPolyline: styled)
            renderer.strokeColor = styled.strokeColor
            renderer.lineWidth = styled.lineWidth
            renderer.lineCap = styled.lineCap
            renderer.lineJoin = .round
            if !styled.dashPattern.isEmpty {
                renderer.lineDashPattern = styled.dashPattern
            }
            return renderer
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let region = mapView.region
            Task { @MainActor in
                await viewModel.handleRegionChange(region)
            }
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended, let map = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: map)
            let coordinate = map.convert(point, toCoordinateFrom: map)
            viewModel.handleTap(at: coordinate)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldReceive touch: UITouch
        ) -> Bool {
            if let view = touch.view {
                if view is TapDotAnnotationView || view.superview is TapDotAnnotationView {
                    return true
                }
                if view is MKAnnotationView || view.superview is MKAnnotationView {
                    return false
                }
            }
            return true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            false
        }
    }
}

final class TapDotAnnotationView: MKAnnotationView {
    static let reuseID = "TapDotAnnotationView"
    private let dotView = UIView()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupView()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }

    private func setupView() {
        frame = CGRect(x: 0, y: 0, width: 16, height: 16)
        centerOffset = CGPoint(x: 0, y: 0)
        backgroundColor = .clear

        dotView.frame = bounds
        dotView.layer.cornerRadius = 8
        dotView.layer.borderWidth = 2
        dotView.layer.borderColor = UIColor.black.cgColor
        dotView.layer.masksToBounds = true
        dotView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(dotView)
    }

    func configure(with dotAnnotation: TapDotAnnotation) {
        dotView.backgroundColor = dotAnnotation.color
    }
}

