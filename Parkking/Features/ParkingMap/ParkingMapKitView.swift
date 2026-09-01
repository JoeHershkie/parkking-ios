import MapKit
import SwiftUI

struct ParkingMapKitView: UIViewRepresentable {
    @Bindable var viewModel: ParkingMapViewModel
    var bottomPadding: CGFloat = 88

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = ParkkingMapView(frame: .zero)
        map.delegate = context.coordinator
        map.isRotateEnabled = true
        map.isPitchEnabled = true
        map.isZoomEnabled = true
        map.isScrollEnabled = true
        map.showsCompass = false
        map.showsTraffic = (viewModel.mapStyle == .driving)
        map.showsUserLocation = viewModel.isLocationAuthorized
        map.selectableMapFeatures = [.pointsOfInterest]
        map.layoutMargins = UIEdgeInsets(
            top: ParkingMapConstants.chromeTopMargin,
            left: 0,
            bottom: ParkingMapConstants.chromeBottomMargin,
            right: 0
        )

        map.preferredConfiguration = viewModel.mapStyle.makeConfiguration()

        map.cameraBoundary = MKMapView.CameraBoundary(
            coordinateRegion: ParkingMapConstants.parkingCoverageRegion
        )
        map.cameraZoomRange = MKMapView.CameraZoomRange(
            minCenterCoordinateDistance: ParkingMapConstants.minCameraDistance,
            maxCenterCoordinateDistance: ParkingMapConstants.maxCameraDistance
        )
        map.setRegion(ParkingMapConstants.cityRegion, animated: false)

        let scale = MKScaleView(mapView: map)
        scale.scaleVisibility = .adaptive
        scale.legendAlignment = .leading
        scale.translatesAutoresizingMaskIntoConstraints = false
        map.addSubview(scale)

        let compass = MKCompassButton(mapView: map)
        compass.compassVisibility = .adaptive
        compass.translatesAutoresizingMaskIntoConstraints = false
        map.addSubview(compass)

        let compassBottomConstraint = compass.bottomAnchor.constraint(
            equalTo: map.safeAreaLayoutGuide.bottomAnchor,
            constant: -(bottomPadding + 148)
        )
        context.coordinator.compassBottomConstraint = compassBottomConstraint

        NSLayoutConstraint.activate([
            scale.topAnchor.constraint(
                equalTo: map.safeAreaLayoutGuide.topAnchor,
                constant: 8
            ),
            scale.centerXAnchor.constraint(equalTo: map.centerXAnchor),

            compass.trailingAnchor.constraint(
                equalTo: map.safeAreaLayoutGuide.trailingAnchor,
                constant: -15
            ),
            compassBottomConstraint,
        ])

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tap.delegate = context.coordinator
        map.addGestureRecognizer(tap)

        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.5
        longPress.delegate = context.coordinator
        map.addGestureRecognizer(longPress)

        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.viewModel = viewModel
        map.showsUserLocation = viewModel.isLocationAuthorized
        if let pending = viewModel.pendingCameraRegion {
            viewModel.pendingCameraRegion = nil
            map.setRegion(pending, animated: true)
        }
        if let targetPitch = viewModel.pendingCameraPitch {
            viewModel.pendingCameraPitch = nil
            let currentCamera = map.camera
            let newCamera = MKMapCamera(
                lookingAtCenter: currentCamera.centerCoordinate,
                fromDistance: currentCamera.centerCoordinateDistance,
                pitch: targetPitch,
                heading: currentCamera.heading
            )
            map.setCamera(newCamera, animated: true)
        }
        context.coordinator.updateBottomPadding(bottomPadding, on: map)
        context.coordinator.syncMapStyle(on: map)
        context.coordinator.syncAnnotations(on: map)
        context.coordinator.syncOverlays(on: map)
    }

    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var viewModel: ParkingMapViewModel
        var compassBottomConstraint: NSLayoutConstraint?
        private var lastMapStyle: MapViewStyle?
        private var lastRenderItems: [ParkingMapRenderItem] = []
        private var lastSelectedIDs: Set<String> = []
        private var lastSearchPinID: String?
        private var lastTapDotID: String?
        private var colorOverlays: [ParkingOverlayBucketKind: ParkingStyledOverlay] = [:]
        private var selectedOverlays: [ParkingStyledOverlay] = []
        private var transitOverlays: [TransitLineOverlay] = []

        init(viewModel: ParkingMapViewModel) {
            self.viewModel = viewModel
        }

        func updateBottomPadding(_ bottomPadding: CGFloat, on map: MKMapView) {
            let target = -(bottomPadding + 148)
            if compassBottomConstraint?.constant != target {
                compassBottomConstraint?.constant = target
                UIView.animate(withDuration: 0.35, delay: 0, options: [.curveEaseInOut, .allowUserInteraction]) {
                    map.layoutIfNeeded()
                }
            }
        }

        func syncMapStyle(on map: MKMapView) {
            if viewModel.mapStyle != lastMapStyle {
                let previousStyle = lastMapStyle
                lastMapStyle = viewModel.mapStyle
                map.showsTraffic = (viewModel.mapStyle == .driving)
                map.preferredConfiguration = viewModel.mapStyle.makeConfiguration()

                if viewModel.mapStyle == .transit {
                    if transitOverlays.isEmpty {
                        transitOverlays = TorontoTransitNetwork.makeOverlays()
                        for overlay in transitOverlays {
                            map.addOverlay(overlay, level: .aboveRoads)
                        }
                    }
                } else if !transitOverlays.isEmpty {
                    map.removeOverlays(transitOverlays)
                    transitOverlays.removeAll()
                }

                if (previousStyle == .satellite || viewModel.mapStyle == .satellite) && previousStyle != nil {
                    syncOverlays(on: map, force: true)
                }
            }
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

        func syncOverlays(on map: MKMapView, force: Bool = false) {
            let items = viewModel.renderItems
            let selectedIDs = viewModel.selectedFeatureIDs
            let itemsChanged = items != lastRenderItems || force
            let selectionChanged = selectedIDs != lastSelectedIDs || force

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
            let isSatellite = (viewModel.mapStyle == .satellite)
            for kind in ParkingOverlayBucketKind.drawOrder {
                guard let ids = plan.colorBuckets[kind], !ids.isEmpty else { continue }
                let groupItems = ids.compactMap { byID[$0] }
                guard !groupItems.isEmpty else { continue }
                let overlay = ParkingStyledOverlay(kind: kind, role: .base, isSatellite: isSatellite, items: groupItems)
                colorOverlays[kind] = overlay
                map.addOverlay(overlay, level: .aboveLabels)
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

            let isSatellite = (viewModel.mapStyle == .satellite)

            // 1. Add border overlays first (rendered under fill)
            for kind in ParkingOverlayBucketKind.drawOrder {
                guard let ids = plan.selectedBuckets[kind], !ids.isEmpty else { continue }
                let groupItems = ids.compactMap { byID[$0] }
                guard !groupItems.isEmpty else { continue }
                let overlay = ParkingStyledOverlay(kind: kind, role: .selectedBorder, isSatellite: isSatellite, items: groupItems)
                selectedOverlays.append(overlay)
                map.addOverlay(overlay, level: .aboveLabels)
            }

            // 2. Add fill overlays second (rendered on top of border with item's color at thickness 8)
            for kind in ParkingOverlayBucketKind.drawOrder {
                guard let ids = plan.selectedBuckets[kind], !ids.isEmpty else { continue }
                let groupItems = ids.compactMap { byID[$0] }
                guard !groupItems.isEmpty else { continue }
                let overlay = ParkingStyledOverlay(kind: kind, role: .selectedFill, isSatellite: isSatellite, items: groupItems)
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
            if let transit = overlay as? TransitLineOverlay {
                let renderer = MKMultiPolylineRenderer(multiPolyline: transit)
                renderer.strokeColor = transit.strokeColor
                renderer.lineWidth = transit.lineWidth
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }

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
            let pitch = mapView.camera.pitch
            Task { @MainActor in
                viewModel.updatePitch(pitch)
                await viewModel.handleRegionChange(region)
            }
        }

        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            if let mapFeature = annotation as? MKMapFeatureAnnotation {
                let title = mapFeature.title ?? "Point of Interest"
                let coordinate = mapFeature.coordinate
                viewModel.selectSearchResult(
                    title: title,
                    subtitle: mapFeature.subtitle ?? nil,
                    coordinate: coordinate,
                    source: .tap
                )
            }
        }

        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            guard let loc = userLocation.location else { return }
            viewModel.updateUserCoordinate(loc.coordinate)
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended, let map = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: map)
            let coordinate = map.convert(point, toCoordinateFrom: map)
            viewModel.handleTap(at: coordinate)
        }

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began, let map = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: map)
            let coordinate = map.convert(point, toCoordinateFrom: map)
            let feedback = UIImpactFeedbackGenerator(style: .medium)
            feedback.impactOccurred()
            viewModel.handleLongPress(at: coordinate)
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
            true
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

final class ParkkingMapView: MKMapView {
    override func layoutSubviews() {
        super.layoutSubviews()
        repositionAttributionAndLogo()
    }

    private func repositionAttributionAndLogo() {
        for subview in subviews {
            let className = NSStringFromClass(type(of: subview))
            if className.contains("AppleLogo") || (subview is UIImageView && subview.bounds.width < 100 && subview.bounds.height < 40 && subview.frame.origin.y > bounds.height - 250) {
                let x = (bounds.width - subview.bounds.width) / 2
                let y = bounds.height - subview.bounds.height - max(safeAreaInsets.bottom, 4)
                subview.frame = CGRect(x: x, y: y, width: subview.bounds.width, height: subview.bounds.height)
            }
        }
    }
}


