import CoreLocation
import Foundation
import MapKit
import Observation
import UIKit

enum SelectionSource: Equatable, Sendable {
    case tap
    case search
    case recent
    case gps
}

@MainActor
@Observable
final class ParkingMapViewModel {
    enum SheetPrompt: Equatable {
        case idle
        case loading
        case failed(String)
        case zoomIn
        case tapPrompt
        case verdict

        var coachingText: String? {
            switch self {
            case .zoomIn:
                return "Zoom in to see parking availability"
            case .tapPrompt:
                return "Tap to find parking"
            default:
                return nil
            }
        }
    }

    var pendingCameraRegion: MKCoordinateRegion?
    var selectedFeatureIDs: Set<String> = []
    var searchPin: SearchPinAnnotation?
    var tapDot: TapDotAnnotation?
    var cardAddress: String?

    var loadState: ParkingDataLoadState = .idle
    var renderItems: [ParkingMapRenderItem] = []
    var curbVisible = false
    var selection: SelectionResult?
    var verdict: CurbVerdict?
    var isResultPresented = false
    var hasTappedSegmentThisSession = false
    var appliedTimeQuery: TimeQuery
    var resolvedQuery: ResolvedTimeQuery?
    var timeChip: String = "Now · 1h"
    var sheetExpanded = false
    var locationLabel = "Search or tap the map"
    var recents: [SavedLocation] = []
    var isLocating = false
    var locationError: LocationClientError?
    var isLocationAuthorized = false
    private(set) var lastFlownRegion: MKCoordinateRegion?
    private(set) var lastSelectionSource: SelectionSource?

    private let dataStore: ParkingDataStore
    private let locationClient: any LocationProviding
    private let recentsStore: any RecentsStoring
    private let geocodingClient: any GeocodingProviding
    private let now: () -> Date
    private let startsClock: Bool
    private let openURL: (URL) -> Void
    private var dataset: ParkingDataset?
    private(set) var viewportGeneration = 0
    private var clockTask: Task<Void, Never>?
    private var reverseGeocodeTask: Task<Void, Never>?
    private var visibleRegion: MKCoordinateRegion?
    private var didAutoLocateThisLaunch = false
    private var awaitingFirstGrant = false

    var isDataReady: Bool {
        if case .loaded = loadState { return true }
        return false
    }

    var sheetPrompt: SheetPrompt {
        switch loadState {
        case .idle, .loading:
            return .loading
        case .failed(let message):
            return .failed(message)
        case .loaded:
            if !curbVisible { return .zoomIn }
            if verdict != nil { return .verdict }
            if !hasTappedSegmentThisSession { return .tapPrompt }
            return .idle
        }
    }

    var nearbyStreetRows: [NearbyStreetRow] {
        guard let selection, let resolvedQuery else { return [] }
        return NearbyCurbSides.streetRows(groups: selection.groups, resolved: resolvedQuery)
    }

    init(
        dataStore: ParkingDataStore = ParkingDataStore(),
        locationClient: (any LocationProviding)? = nil,
        recentsStore: (any RecentsStoring)? = nil,
        geocodingClient: (any GeocodingProviding)? = nil,
        now: @escaping () -> Date = Date.init,
        dataset: ParkingDataset? = nil,
        startsClock: Bool = true,
        openURL: ((URL) -> Void)? = nil
    ) {
        self.dataStore = dataStore
        self.locationClient = locationClient ?? LocationClient()
        self.recentsStore = recentsStore ?? RecentsStore()
        self.geocodingClient = geocodingClient ?? CLGeocodingClient()
        self.now = now
        self.startsClock = startsClock
        self.openURL = openURL ?? { UIApplication.shared.open($0) }
        self.appliedTimeQuery = ParkingTimeQuery.createNowTimeQuery(now: now())
        self.recents = self.recentsStore.recents
        self.isLocationAuthorized = self.locationClient.isAuthorized

        if let dataset {
            install(dataset)
        }
        resolveAppliedQuery(recomputeViewport: false)
        self.locationClient.delegate = self
    }

    func onAppear() {
        if ProcessInfo.processInfo.arguments.contains("-demoNeighborhood") {
            pendingCameraRegion = ParkingMapConstants.neighborhoodRegion(
                around: ParkingMapConstants.torontoCenter
            )
            curbVisible = true
        }
        Task { await start() }
        if startsClock {
            startClock()
        }
    }

    func onDisappear() {
        clockTask?.cancel()
        clockTask = nil
    }

    func start() async {
        await loadIfNeeded()
        await maybeAutoLocate()
    }

    func retry() {
        loadState = .idle
        Task { await start() }
    }

    func sceneBecameActive() {
        hasTappedSegmentThisSession = false
        if startsClock {
            startClock()
        }
        locationClient.refreshAuthorizationStatus()
        Task { await handleAuthorizationChange() }
        refreshNowIfNeeded(recomputeViewport: true)
    }

    func sceneBecameInactive() {
        clockTask?.cancel()
        clockTask = nil
    }

    func handleRegionChange(_ region: MKCoordinateRegion) async {
        visibleRegion = region
        curbVisible = ParkingMapConstants.visibleWidthMeters(region)
            <= ParkingMapConstants.curbVisibleMaxWidthMeters
        await refreshViewport(region: region)
    }

    func handleTap(at coordinate: CLLocationCoordinate2D) {
        selectAtPoint(coordinate: coordinate, label: nil, source: .tap)
    }

    func selectGroup(_ groupKey: String) {
        guard var selection else { return }
        guard let group = selection.groups.first(where: { $0.groupKey == groupKey }) else {
            return
        }
        selection.selectedGroupKey = groupKey
        selection.selected = group
        self.selection = selection
        if let street = group.street as String? {
            locationLabel = street
        }
        if tapDot != nil {
            tapDot?.color = dotColor(for: group, resolved: resolvedQuery)
        }
        syncSelectedFeatureIDs()
        recomputeVerdict()
    }

    @discardableResult
    func selectSearchResult(
        title: String,
        subtitle: String? = nil,
        coordinate: CLLocationCoordinate2D,
        source: SelectionSource = .search
    ) -> Bool {
        guard ParkingMapConstants.contains(coordinate) else { return false }
        selectAtPoint(
            coordinate: coordinate,
            label: title,
            subtitle: subtitle,
            source: source
        )
        return true
    }

    @discardableResult
    func selectSearchResult(
        label: String,
        coordinate: CLLocationCoordinate2D,
        source: SelectionSource
    ) -> Bool {
        selectSearchResult(
            title: label,
            subtitle: nil,
            coordinate: coordinate,
            source: source
        )
    }

    func applyTimeQuery(_ query: TimeQuery) {
        var next = query
        next.requestedDurationMinutes = ParkingTimeQuery.clampDuration(next.requestedDurationMinutes)
        appliedTimeQuery = next
        resolveAppliedQuery(recomputeViewport: true)
    }

    func clearSearchPin() {
        searchPin = nil
    }

    func dismissResult() {
        reverseGeocodeTask?.cancel()
        reverseGeocodeTask = nil
        isResultPresented = false
        selection = nil
        verdict = nil
        selectedFeatureIDs = []
        tapDot = nil
        cardAddress = nil
        locationLabel = "Search or tap the map"
    }

    func clearSelection() {
        dismissResult()
    }

    func tapLocate() {
        Task { await tapLocateAsync() }
    }

    func tapLocateAsync() async {
        guard isDataReady else { return }
        locationError = nil

        if !locationClient.servicesEnabled {
            locationError = .servicesDisabled
            return
        }

        switch locationClient.authorizationStatus {
        case .notDetermined:
            awaitingFirstGrant = true
            locationClient.requestWhenInUsePermission()
        case .restricted:
            locationError = .restricted
        case .denied:
            locationError = .denied
        case .authorizedAlways, .authorizedWhenInUse:
            await performLocate()
        @unknown default:
            break
        }
    }

    func handleAuthorizationChange() async {
        isLocationAuthorized = locationClient.isAuthorized
        if !locationClient.servicesEnabled {
            locationError = .servicesDisabled
            awaitingFirstGrant = false
            return
        }

        switch locationClient.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locationError = nil
            if awaitingFirstGrant {
                awaitingFirstGrant = false
                await performLocate()
            } else {
                await maybeAutoLocate()
            }
        case .denied:
            locationError = .denied
            awaitingFirstGrant = false
        case .restricted:
            locationError = .restricted
            awaitingFirstGrant = false
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    func removeRecent(id: String) {
        recents = recentsStore.remove(id: id)
    }

    func clearRecents() {
        recents = recentsStore.clear()
    }

    func selectAtPoint(
        coordinate: CLLocationCoordinate2D,
        label: String?,
        subtitle: String? = nil,
        source: SelectionSource
    ) {
        reverseGeocodeTask?.cancel()
        reverseGeocodeTask = nil

        let fly = source != .tap
        let recordRecent = source == .search || source == .recent

        if fly {
            let region = ParkingMapConstants.neighborhoodRegion(around: coordinate)
            pendingCameraRegion = region
            lastFlownRegion = region
            visibleRegion = region
            curbVisible = true
        }

        if source == .search || source == .recent || source == .gps {
            searchPin = SearchPinAnnotation(
                coordinate: coordinate,
                title: label,
                subtitle: subtitle,
                source: source
            )
            tapDot = nil
        } else {
            searchPin = nil
        }

        guard let dataset else { return }
        let point = LngLat(lng: coordinate.longitude, lat: coordinate.latitude)
        let searchDistance = (source == .tap)
            ? CurbSelection.tapMaxDistanceMeters
            : CurbSelection.searchMaxDistanceMeters
        let padDeg = CurbGeometry.degreesPad(
            forMeters: searchDistance,
            atLatitude: point.lat
        )
        let subset = dataset.index.queryBBox(
            BBox(minLng: point.lng, minLat: point.lat, maxLng: point.lng, maxLat: point.lat),
            padDeg: padDeg
        )
        let result = CurbSelection.selectNearestCurb(
            features: subset,
            point: point,
            maxDistanceMeters: searchDistance,
            preferredGroupKey: nil
        )

        lastSelectionSource = source
        selection = result

        if recordRecent, let label {
            recents = recentsStore.add(
                label: label,
                subtitle: subtitle,
                coordinate: coordinate
            )
        }

        syncSelectedFeatureIDs()
        recomputeVerdict()

        if source == .tap {
            if let selected = result.selected {
                isResultPresented = true
                hasTappedSegmentThisSession = true

                let nearestCoord: CLLocationCoordinate2D
                if let primaryFeature = selected.features.first(where: { selected.highlightFeatureIDs.contains($0.id) }) ?? selected.features.first,
                   let nearest = CurbGeometry.nearestPointOnFeatureMeters(point: point, feature: primaryFeature) {
                    nearestCoord = CLLocationCoordinate2D(latitude: nearest.point.lat, longitude: nearest.point.lng)
                } else {
                    nearestCoord = coordinate
                }

                let color = dotColor(for: selected, resolved: resolvedQuery)
                tapDot = TapDotAnnotation(coordinate: nearestCoord, color: color)

                cardAddress = selected.street
                locationLabel = selected.street

                let lookupCoord = coordinate
                reverseGeocodeTask = Task { [weak self] in
                    guard let self else { return }
                    if let address = await self.geocodingClient.reverseGeocode(coordinate: lookupCoord) {
                        await MainActor.run {
                            self.cardAddress = address
                            self.locationLabel = address
                        }
                    }
                }
            } else {
                tapDot = nil
                isResultPresented = false
                locationLabel = "Search or tap the map"
            }
        } else {
            isResultPresented = true
            hasTappedSegmentThisSession = true
            tapDot = nil

            let displayTitle = label ?? subtitle ?? result.selected?.street
            cardAddress = displayTitle
            locationLabel = displayTitle
                ?? String(
                    format: "%.5f°N, %.5f°W",
                    coordinate.latitude,
                    abs(coordinate.longitude)
                )

            let isCoordinateOrGeneric = label == nil
                || label == "Current location"
                || label?.contains("°") == true
                || (label?.split(separator: ",").count == 2 && Double(label!.split(separator: ",")[0].trimmingCharacters(in: .whitespaces)) != nil)

            if isCoordinateOrGeneric {
                let lookupCoord = coordinate
                reverseGeocodeTask = Task { [weak self] in
                    guard let self else { return }
                    if let address = await self.geocodingClient.reverseGeocode(coordinate: lookupCoord) {
                        await MainActor.run {
                            self.cardAddress = address
                            self.locationLabel = address
                        }
                    }
                }
            }
        }

        if fly, let region = visibleRegion {
            Task { await refreshViewport(region: region) }
        }
    }

    func selectAtPoint(
        coordinate: CLLocationCoordinate2D,
        label: String?,
        source: SelectionSource
    ) {
        selectAtPoint(
            coordinate: coordinate,
            label: label,
            subtitle: nil,
            source: source
        )
    }

    private func syncSelectedFeatureIDs() {
        selectedFeatureIDs = Set(selection?.selected?.highlightFeatureIDs.map(\.rawValue) ?? [])
    }

    private func install(_ dataset: ParkingDataset) {
        self.dataset = dataset
        loadState = .loaded(
            featureCount: dataset.features.count + dataset.skippedPoints,
            lineFeatureCount: dataset.features.count,
            skippedPoints: dataset.skippedPoints
        )
    }

    private func loadIfNeeded() async {
        if dataset != nil { return }
        loadState = .loading
        do {
            let loaded = try await dataStore.loadBundled()
            install(loaded)
            resolveAppliedQuery(recomputeViewport: true)
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    private func startClock() {
        clockTask?.cancel()
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let now = self.now()
                var cal = Calendar(identifier: .gregorian)
                cal.timeZone = ParkingTimeQuery.torontoTimeZone
                let seconds = cal.component(.second, from: now)
                let toNextMinute = max(1.0, Double(60 - seconds))
                let sleepSeconds = min(30.0, toNextMinute)
                try? await Task.sleep(nanoseconds: UInt64(sleepSeconds * 1_000_000_000))
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    self.refreshNowIfNeeded(recomputeViewport: true)
                }
            }
        }
    }

    private func refreshNowIfNeeded(recomputeViewport: Bool) {
        guard appliedTimeQuery.mode == .now else { return }
        appliedTimeQuery = ParkingTimeQuery.createNowTimeQuery(
            durationMinutes: appliedTimeQuery.requestedDurationMinutes,
            preset: appliedTimeQuery.durationPreset,
            now: now()
        )
        resolveAppliedQuery(recomputeViewport: recomputeViewport)
    }

    private func resolveAppliedQuery(recomputeViewport: Bool) {
        let resolved = ParkingTimeQuery.resolveTimeQuery(appliedTimeQuery, now: now())
        resolvedQuery = resolved
        timeChip = ParkingTimeQuery.formatTimeQueryChip(query: appliedTimeQuery, resolved: resolved)
        recomputeVerdict()
        if let group = selection?.selected, tapDot != nil {
            tapDot?.color = dotColor(for: group, resolved: resolved)
        }
        if recomputeViewport, let region = visibleRegion {
            Task { await refreshViewport(region: region) }
        }
    }

    private func dotColor(for group: CurbSideGroup, resolved: ResolvedTimeQuery?) -> UIColor {
        guard let resolved else { return .systemGreen }
        let features = group.verdictFeatures
        let composed = CurbVerdictComposer.composeCurbVerdictForQuery(
            features: features,
            resolved: resolved,
            street: group.street,
            side: group.side,
            sideDisplay: group.sideDisplay
        )
        switch composed.status {
        case .parkingAllowed, .likelyAllowed:
            return .systemGreen
        case .scheduleUnclear, .partiallyAllowed:
            return .systemOrange
        case .notAllowed:
            return .systemRed
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
        let verdictFeatures = selected.verdictFeatures
        verdict = CurbVerdictComposer.composeCurbVerdictForQuery(
            features: verdictFeatures,
            resolved: resolved,
            street: selected.street,
            side: selected.side,
            sideDisplay: selected.sideDisplay
        )
    }

    private func maybeAutoLocate() async {
        guard !didAutoLocateThisLaunch else { return }
        guard isDataReady else { return }
        guard locationClient.servicesEnabled else { return }
        guard locationClient.isAuthorized else { return }
        didAutoLocateThisLaunch = true
        await performLocate()
    }

    private func performLocate() async {
        isLocating = true
        defer { isLocating = false }
        do {
            let location = try await locationClient.requestOneShotLocation()
            didAutoLocateThisLaunch = true
            selectAtPoint(
                coordinate: location.coordinate,
                label: "Current location",
                source: .gps
            )
        } catch let error as LocationClientError {
            locationError = error
        } catch {
            locationError = .failed(error.localizedDescription)
        }
    }

    private func refreshViewport(region: MKCoordinateRegion) async {
        guard let dataset, let resolved = resolvedQuery else {
            if !renderItems.isEmpty { renderItems = [] }
            return
        }
        guard curbVisible else {
            if !renderItems.isEmpty { renderItems = [] }
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
                let uncertain = feature.properties.hasUncertainCurbPlacement
                for (partIndex, coords) in feature.coordinateParts.enumerated() {
                    guard coords.count >= 2 else { continue }
                    renders.append(
                        ParkingMapRenderItem(
                            featureID: feature.id,
                            partIndex: partIndex,
                            coordinates: coords,
                            severity: severity,
                            polarity: polarity,
                            isSelected: false,
                            isUncertainPlacement: uncertain
                        )
                    )
                }
            }
            renders.sort { $0.severity < $1.severity }
            return renders
        }.value

        guard generation == viewportGeneration else { return }
        if items != renderItems {
            renderItems = items
        }
    }
}

extension ParkingMapViewModel: LocationClientDelegate {
    func locationClientDidChangeAuthorization(_ client: LocationProviding) {
        Task { await handleAuthorizationChange() }
    }
}
