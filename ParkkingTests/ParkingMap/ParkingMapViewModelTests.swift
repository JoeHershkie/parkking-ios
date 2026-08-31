import CoreLocation
import MapKit
import Testing
@testable import Parkking

@MainActor
@Suite("Parking map selection and coaching")
struct ParkingMapViewModelTests {
    @Test("search and recents fly and record recents, GPS flies without recents, and presents verdict card")
    func searchRecentAndGPSSelection() async {
        let recents = ParkingMapTestFixtures.recentsStore()
        let location = MockLocationClient()
        let geocoding = MockGeocodingClient(defaultResult: "100 Queen St W")
        let vm = ParkingMapTestFixtures.viewModel(location: location, recents: recents, geocoding: geocoding)
        await vm.start()

        let accepted = vm.selectSearchResult(
            title: "City Hall",
            subtitle: "100 Queen St W, Toronto, ON",
            coordinate: ParkingMapTestFixtures.queenNorth,
            source: .search
        )
        #expect(accepted)
        #expect(vm.lastSelectionSource == .search)
        #expect(vm.isResultPresented == true)
        #expect(vm.cardAddress == "City Hall")
        #expect(vm.lastFlownRegion != nil)
        #expect(
            ParkingMapConstants.visibleWidthMeters(vm.lastFlownRegion!)
                < ParkingMapConstants.curbVisibleMaxWidthMeters
        )
        #expect(vm.selection?.selected != nil)
        #expect(vm.searchPin != nil)
        #expect(vm.tapDot == nil)
        #expect(vm.searchPin?.title == "City Hall")
        #expect(vm.searchPin?.subtitle == "100 Queen St W, Toronto, ON")
        #expect(vm.searchPin?.coordinate.latitude == ParkingMapTestFixtures.queenNorth.latitude)
        #expect(vm.searchPin?.coordinate.longitude == ParkingMapTestFixtures.queenNorth.longitude)
        #expect(recents.recents.first?.label == "City Hall")
        #expect(recents.recents.first?.subtitle == "100 Queen St W, Toronto, ON")

        vm.selectAtPoint(
            coordinate: ParkingMapTestFixtures.queenNorth,
            label: "City Hall",
            subtitle: "100 Queen St W, Toronto, ON",
            source: .recent
        )
        #expect(vm.lastSelectionSource == .recent)
        #expect(vm.isResultPresented == true)
        #expect(vm.searchPin?.title == "City Hall")
        #expect(vm.searchPin?.subtitle == "100 Queen St W, Toronto, ON")
        #expect(vm.tapDot == nil)
        #expect(recents.recents.count == 1)

        vm.clearSearchPin()
        #expect(vm.searchPin == nil)

        vm.selectAtPoint(
            coordinate: ParkingMapTestFixtures.queenNorth,
            label: "Current location",
            source: .gps
        )
        #expect(vm.lastSelectionSource == .gps)
        #expect(vm.isResultPresented == true)
        #expect(recents.recents.contains { $0.label == "Current location" } == false)
    }

    @Test("rejects out-of-coverage search results")
    func rejectsOutOfCoverageSearch() async {
        let recents = ParkingMapTestFixtures.recentsStore()
        let vm = ParkingMapTestFixtures.viewModel(recents: recents)
        let accepted = vm.selectSearchResult(
            title: "Vancouver",
            subtitle: "Vancouver, BC",
            coordinate: ParkingMapTestFixtures.vancouver,
            source: .search
        )
        #expect(accepted == false)
        #expect(recents.recents.isEmpty)
        #expect(vm.searchPin == nil)
        #expect(vm.tapDot == nil)
        #expect(vm.lastFlownRegion == nil)
        #expect(vm.selection == nil)
        #expect(vm.isResultPresented == false)
    }

    @Test("manual tap selects without flying or writing recents, presents result card with dot and geocoded address")
    func manualTapRendersDotAndReverseGeocodes() async {
        let recents = ParkingMapTestFixtures.recentsStore()
        let geocoding = MockGeocodingClient(defaultResult: "124 Queen St W")
        let vm = ParkingMapTestFixtures.viewModel(recents: recents, geocoding: geocoding)
        await vm.start()
        await vm.handleRegionChange(ParkingMapTestFixtures.zoomedInRegion)

        vm.handleTap(at: ParkingMapTestFixtures.queenNorth)
        #expect(vm.lastSelectionSource == .tap)
        #expect(vm.isResultPresented == true)
        #expect(vm.lastFlownRegion == nil)
        #expect(vm.selection?.selected != nil)
        #expect(vm.searchPin == nil)
        #expect(vm.tapDot != nil)
        #expect(recents.recents.isEmpty)
        #expect(vm.sheetPrompt == .verdict)

        // Wait for async reverse geocoding to populate cardAddress
        for _ in 0..<20 {
            if vm.cardAddress == "124 Queen St W" { break }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        #expect(vm.cardAddress == "124 Queen St W")

        vm.dismissResult()
        #expect(vm.isResultPresented == false)
        #expect(vm.selection == nil)
        #expect(vm.verdict == nil)
        #expect(vm.tapDot == nil)
        #expect(vm.cardAddress == nil)
        #expect(vm.selectedFeatureIDs.isEmpty)
    }

    @Test("coordinate / non-address search snaps to nearest street segment and sets verdict")
    func coordinateSearchSnapsToNearestStreetSegment() async {
        let geocoding = MockGeocodingClient(defaultResult: "100 Queen St W")
        let vm = ParkingMapTestFixtures.viewModel(geocoding: geocoding)
        await vm.start()

        // Point set back 30m from Queen St
        let setbackCoord = CLLocationCoordinate2D(latitude: 43.6503, longitude: -79.4005)
        let accepted = vm.selectSearchResult(
            title: "43.6503, -79.4005",
            subtitle: nil,
            coordinate: setbackCoord,
            source: .search
        )
        #expect(accepted)
        #expect(vm.selection?.selected != nil)
        #expect(vm.isResultPresented == true)
        #expect(vm.searchPin != nil)
        #expect(vm.tapDot == nil)

        for _ in 0..<20 {
            if vm.cardAddress == "100 Queen St W" { break }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        #expect(vm.cardAddress == "100 Queen St W")
    }

    @Test("zoom threshold changes coaching and never auto-selects")
    func zoomThresholdCoachingWithoutSelection() async {
        let vm = ParkingMapTestFixtures.viewModel()
        await vm.start()
        await vm.handleRegionChange(ParkingMapTestFixtures.zoomedOutRegion)
        #expect(vm.curbVisible == false)
        #expect(vm.renderItems.isEmpty)
        #expect(vm.selection == nil)
        #expect(vm.sheetPrompt == .zoomIn)
        #expect(vm.sheetPrompt.coachingText == "Zoom in to see parking availability")

        await vm.handleRegionChange(ParkingMapTestFixtures.zoomedInRegion)
        #expect(vm.curbVisible)
        #expect(vm.selection == nil)
        #expect(vm.lastSelectionSource == nil)
        #expect(vm.sheetPrompt == .tapPrompt)
        #expect(vm.sheetPrompt.coachingText == "Tap to find parking")
    }

    @Test("Now duration is preserved across ticks and custom queries do not reset")
    func timeQueryPersistence() async {
        var now = Date(timeIntervalSince1970: 1_747_764_000) // 2025-05-20 15:00 EDT-ish
        let vm = ParkingMapTestFixtures.viewModel(now: { now })
        await vm.start()

        vm.applyTimeQuery(
            ParkingTimeQuery.createNowTimeQuery(
                durationMinutes: 30,
                preset: .minutes(30),
                now: now
            )
        )
        #expect(vm.timeChip == "Now · 30m")
        now = now.addingTimeInterval(120)
        vm.sceneBecameActive()
        #expect(vm.appliedTimeQuery.requestedDurationMinutes == 30)
        #expect(vm.appliedTimeQuery.mode == .now)
        #expect(vm.timeChip == "Now · 30m")

        let custom = TimeQuery(
            mode: .custom,
            date: "2025-05-20",
            startMinute: 22 * 60,
            requestedDurationMinutes: 180,
            durationPreset: .minutes(180)
        )
        vm.applyTimeQuery(custom)
        now = now.addingTimeInterval(3_600)
        vm.sceneBecameActive()
        #expect(vm.appliedTimeQuery.mode == .custom)
        #expect(vm.appliedTimeQuery.requestedDurationMinutes == 180)
        #expect(vm.appliedTimeQuery.date == "2025-05-20")
        #expect(vm.resolvedQuery?.truncatedAtMidnight == true)
    }

    @Test("applying preset or custom time query updates timeChip and re-evaluates active verdict")
    func timeQueryApplicationReevaluatesVerdict() async {
        let now = ParkingTimeQuery.date(fromTorontoDateString: "2025-05-20", minuteOfDay: 14 * 60)
        let vm = ParkingMapTestFixtures.viewModel(now: { now })
        await vm.start()
        await vm.handleRegionChange(ParkingMapTestFixtures.zoomedInRegion)

        vm.handleTap(at: ParkingMapTestFixtures.queenNorth)
        #expect(vm.isResultPresented == true)
        #expect(vm.verdict != nil)
        #expect(vm.timeChip == "Now · 1h")

        // Switch to 3h preset
        vm.applyTimeQuery(
            ParkingTimeQuery.createNowTimeQuery(
                durationMinutes: 180,
                preset: .minutes(180),
                now: now
            )
        )
        #expect(vm.timeChip == "Now · 3h")
        #expect(vm.resolvedQuery?.requestedDurationMinutes == 180)
        #expect(vm.verdict != nil)

        // Switch to custom time
        let custom = TimeQuery(
            mode: .custom,
            date: "2025-05-20",
            startMinute: 19 * 60,
            requestedDurationMinutes: 120,
            durationPreset: .minutes(120)
        )
        vm.applyTimeQuery(custom)
        #expect(vm.appliedTimeQuery.mode == .custom)
        #expect(vm.timeChip == "19:00 · 2h")
        #expect(vm.resolvedQuery?.slot.minuteOfDay == 19 * 60)
        #expect(vm.verdict != nil)
    }

    @Test("load and error prompts take priority")
    func loadAndErrorPriority() {
        let vm = ParkingMapViewModel(
            locationClient: MockLocationClient(),
            recentsStore: ParkingMapTestFixtures.recentsStore(),
            startsClock: false
        )
        vm.loadState = .loading
        #expect(vm.sheetPrompt == .loading)
        vm.loadState = .failed("boom")
        #expect(vm.sheetPrompt == .failed("boom"))
    }

    @Test("tap and selectGroup do not rebuild the viewport")
    func tapAndSelectGroupSkipViewportRebuild() async {
        let vm = ParkingMapTestFixtures.viewModel()
        await vm.start()
        await vm.handleRegionChange(ParkingMapTestFixtures.zoomedInRegion)
        let generation = vm.viewportGeneration

        vm.handleTap(at: ParkingMapTestFixtures.queenNorth)
        #expect(vm.viewportGeneration == generation)
        #expect(vm.selectedFeatureIDs.isEmpty == false)

        if let other = vm.nearbyStreetRows.flatMap(\.sides).first(where: {
            $0.groupKey != vm.selection?.selectedGroupKey
        }) {
            vm.selectGroup(other.groupKey)
            #expect(vm.viewportGeneration == generation)
            #expect(vm.selectedFeatureIDs.isEmpty == false)
        }
    }

    @Test("search fly-to sets a pending camera region")
    func searchSetsPendingCameraRegion() async {
        let vm = ParkingMapTestFixtures.viewModel()
        await vm.start()
        let accepted = vm.selectSearchResult(
            label: "City Hall",
            coordinate: ParkingMapTestFixtures.queenNorth,
            source: .search
        )
        #expect(accepted)
        #expect(vm.pendingCameraRegion != nil)
        #expect(vm.lastFlownRegion != nil)
    }

    @Test("tapping the opposite curb side replaces the selection")
    func tappingOppositeSideReplacesSelection() async {
        let vm = ParkingMapTestFixtures.viewModel()
        await vm.start()
        await vm.handleRegionChange(ParkingMapTestFixtures.zoomedInRegion)
        vm.handleTap(at: ParkingMapTestFixtures.queenNorth)
        let firstSide = vm.selection?.selected?.side
        #expect(firstSide != nil)

        vm.handleTap(at: ParkingMapTestFixtures.queenSouth)
        #expect(vm.selection?.selected?.side != firstSide)
        #expect(vm.selectedFeatureIDs.count == 1)
    }
}
