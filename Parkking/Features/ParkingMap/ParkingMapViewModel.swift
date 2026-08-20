import CoreLocation
import Foundation
import MapKit
import Observation
import SwiftUI

@MainActor
@Observable
final class ParkingMapViewModel {
    enum SheetPrompt: Equatable {
        case loading
        case failed(String)
        case zoomIn
        case tapPrompt
        case verdict
    }

    var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: ParkingMapConstants.torontoCenter,
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
    )

    var loadState: ParkingDataLoadState = .idle
    var renderItems: [ParkingMapRenderItem] = []
    var curbVisible = false
    var selection: SelectionResult?
    var verdict: CurbVerdict?
    var resolvedQuery: ResolvedTimeQuery?
    var timeChip: String = "Now · 1h"
    var sheetExpanded = false

    private let dataStore = ParkingDataStore()
    private var dataset: ParkingDataset?
    private var viewportGeneration = 0
    private var clockTask: Task<Void, Never>?
    private var visibleRegion: MKCoordinateRegion?

    var sheetPrompt: SheetPrompt {
        switch loadState {
        case .idle, .loading:
            return .loading
        case .failed(let message):
            return .failed(message)
        case .loaded:
            if !curbVisible { return .zoomIn }
            if verdict == nil { return .tapPrompt }
            return .verdict
        }
    }

    func onAppear() {
        if ProcessInfo.processInfo.arguments.contains("-demoNeighborhood") {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: ParkingMapConstants.torontoCenter,
                    span: MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004)
                )
            )
            curbVisible = true
        }
        Task { await loadIfNeeded() }
        startClock()
    }

    func onDisappear() {
        clockTask?.cancel()
        clockTask = nil
    }

    func retry() {
        loadState = .idle
        Task { await loadIfNeeded() }
    }

    func sceneBecameActive() {
        startClock()
        refreshNowQuery(recomputeViewport: true)
    }

    func sceneBecameInactive() {
        clockTask?.cancel()
        clockTask = nil
    }

    func handleCameraChange(_ context: MapCameraUpdateContext) {
        visibleRegion = context.region
        let width = approximateVisibleWidthMeters(context.region)
        curbVisible = width <= ParkingMapConstants.curbVisibleMaxWidthMeters
        Task { await refreshViewport(region: context.region) }
    }

    func handleTap(at coordinate: CLLocationCoordinate2D) {
        guard let dataset else { return }
        let point = LngLat(lng: coordinate.longitude, lat: coordinate.latitude)
        let preferred = selection?.selectedGroupKey
        // Indexed 80 m search box, then exact point-to-line ranking.
        let padDeg = CurbGeometry.degreesPad(forMeters: 80, atLatitude: point.lat)
        let subset = dataset.index.queryBBox(
            BBox(minLng: point.lng, minLat: point.lat, maxLng: point.lng, maxLat: point.lat),
            padDeg: padDeg
        )
        let result = CurbSelection.selectNearestCurb(
            features: subset,
            point: point,
            preferredGroupKey: preferred
        )
        selection = result
        recomputeVerdict()
        if let region = visibleRegion {
            Task { await refreshViewport(region: region) }
        }
    }

    func selectGroup(_ groupKey: String) {
        guard var selection else { return }
        guard let group = selection.groups.first(where: { $0.groupKey == groupKey }) else {
            return
        }
        selection.selectedGroupKey = groupKey
        selection.selected = group
        self.selection = selection
        recomputeVerdict()
        if let region = visibleRegion {
            Task { await refreshViewport(region: region) }
        }
    }

    private func loadIfNeeded() async {
        if dataset != nil { return }
        loadState = .loading
        do {
            let loaded = try await dataStore.loadBundled()
            dataset = loaded
            loadState = .loaded(
                featureCount: loaded.features.count + loaded.skippedPoints,
                lineFeatureCount: loaded.features.count,
                skippedPoints: loaded.skippedPoints
            )
            refreshNowQuery(recomputeViewport: true)
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    private func startClock() {
        clockTask?.cancel()
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let now = Date()
                var cal = Calendar(identifier: .gregorian)
                cal.timeZone = ParkingTimeQuery.torontoTimeZone
                let seconds = cal.component(.second, from: now)
                let toNextMinute = max(1.0, Double(60 - seconds))
                let sleepSeconds = min(30.0, toNextMinute)
                try? await Task.sleep(nanoseconds: UInt64(sleepSeconds * 1_000_000_000))
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    self.refreshNowQuery(recomputeViewport: true)
                }
            }
        }
    }

    private func refreshNowQuery(recomputeViewport: Bool) {
        let query = ParkingTimeQuery.createNowTimeQuery(durationMinutes: 60)
        let resolved = ParkingTimeQuery.resolveTimeQuery(query)
        resolvedQuery = resolved
        timeChip = ParkingTimeQuery.formatTimeQueryChip(query: query, resolved: resolved)
        recomputeVerdict()
        if recomputeViewport, let region = visibleRegion {
            Task { await refreshViewport(region: region) }
        }
    }

    private func recomputeVerdict() {
        guard let resolved = resolvedQuery else { return }
        guard let selected = selection?.selected else {
            if selection != nil {
                verdict = CurbVerdictComposer.composeCurbVerdictForQuery(
                    features: [],
                    resolved: resolved
                )
            } else {
                verdict = nil
            }
            return
        }
        verdict = CurbVerdictComposer.composeCurbVerdictForQuery(
            features: selected.features,
            resolved: resolved,
            street: selected.street,
            side: selected.side,
            sideDisplay: selected.sideDisplay
        )
    }

    private func refreshViewport(region: MKCoordinateRegion) async {
        guard let dataset, let resolved = resolvedQuery else {
            renderItems = []
            return
        }
        guard curbVisible else {
            renderItems = []
            return
        }

        viewportGeneration += 1
        let generation = viewportGeneration
        let bbox = BBox(
            minLng: region.center.longitude - region.span.longitudeDelta / 2,
            minLat: region.center.latitude - region.span.latitudeDelta / 2,
            maxLng: region.center.longitude + region.span.longitudeDelta / 2,
            maxLat: region.center.latitude + region.span.latitudeDelta / 2
        )
        let selectedIDs = Set(selection?.selected?.featureIDs.map(\.rawValue) ?? [])
        let index = dataset.index

        let items: [ParkingMapRenderItem] = await Task.detached(priority: .userInitiated) {
            let subset = index.queryBBox(bbox, padDeg: ParkingMapConstants.viewportPadDegrees)
            let enriched = ParkingSpatialIndex.enrichFeaturesSubset(
                subset,
                slot: resolved.slot,
                includeUnknown: true,
                endMinuteOfDay: resolved.effectiveEndMinute
            )
            var renders: [ParkingMapRenderItem] = []
            for feature in enriched.features {
                let polarity = feature.properties.polarity ?? .unknown
                let severity = feature.properties.severity
                    ?? ParkingSpatialIndex.severityOrder(
                        polarity: polarity,
                        unparsed: feature.properties.unparsed
                    )
                let selected = selectedIDs.contains(feature.id.rawValue)
                let parts = CurbGeometry.lineParts(feature.geometry)
                for (partIndex, part) in parts.enumerated() {
                    let coords: [CLLocationCoordinate2D] = part.compactMap { pair in
                        guard pair.count >= 2 else { return nil }
                        return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
                    }
                    guard coords.count >= 2 else { continue }
                    renders.append(
                        ParkingMapRenderItem(
                            featureID: feature.id,
                            partIndex: partIndex,
                            coordinates: coords,
                            severity: severity,
                            polarity: polarity,
                            isSelected: selected
                        )
                    )
                }
            }
            // Draw order: low severity first, selected last.
            renders.sort { a, b in
                if a.isSelected != b.isSelected { return !a.isSelected && b.isSelected }
                return a.severity < b.severity
            }
            return renders
        }.value

        guard generation == viewportGeneration else { return }
        renderItems = items
    }

    private func approximateVisibleWidthMeters(_ region: MKCoordinateRegion) -> CLLocationDistance {
        let lat = region.center.latitude * .pi / 180
        let metersPerDegreeLng = cos(lat) * 111_320
        return abs(region.span.longitudeDelta) * metersPerDegreeLng
    }
}
