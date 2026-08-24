import CoreLocation
import MapKit
import Testing
@testable import Parkking

@MainActor
@Suite("Parking map selection and coaching")
struct ParkingMapViewModelTests {
    @Test("search and recents fly and record recents, GPS flies without recents")
    func searchRecentAndGPSSelection() async {
        let recents = ParkingMapTestFixtures.recentsStore()
        let location = MockLocationClient()
        let vm = ParkingMapTestFixtures.viewModel(location: location, recents: recents)
        await vm.start()

        let accepted = vm.selectSearchResult(
            label: "City Hall",
            coordinate: ParkingMapTestFixtures.queenNorth,
            source: .search
        )
        #expect(accepted)
        #expect(vm.lastSelectionSource == .search)
        #expect(vm.lastFlownRegion != nil)
        #expect(
            ParkingMapConstants.visibleWidthMeters(vm.lastFlownRegion!)
                < ParkingMapConstants.curbVisibleMaxWidthMeters
        )
        #expect(vm.selection?.selected != nil)
        #expect(recents.recents.first?.label == "City Hall")

        vm.selectAtPoint(
            coordinate: ParkingMapTestFixtures.queenNorth,
            label: "City Hall",
            source: .recent
        )
        #expect(vm.lastSelectionSource == .recent)
        #expect(recents.recents.count == 1)

        vm.selectAtPoint(
            coordinate: ParkingMapTestFixtures.queenNorth,
            label: "Current location",
            source: .gps
        )
        #expect(vm.lastSelectionSource == .gps)
        #expect(recents.recents.contains { $0.label == "Current location" } == false)
    }

    @Test("rejects out-of-coverage search results")
    func rejectsOutOfCoverageSearch() async {
        let recents = ParkingMapTestFixtures.recentsStore()
        let vm = ParkingMapTestFixtures.viewModel(recents: recents)
        let accepted = vm.selectSearchResult(
            label: "Vancouver",
            coordinate: ParkingMapTestFixtures.vancouver,
            source: .search
        )
        #expect(accepted == false)
        #expect(recents.recents.isEmpty)
        #expect(vm.lastFlownRegion == nil)
        #expect(vm.selection == nil)
    }

    @Test("manual tap selects without flying or writing recents")
    func manualTapDoesNotFlyOrRecord() async {
        let recents = ParkingMapTestFixtures.recentsStore()
        let vm = ParkingMapTestFixtures.viewModel(recents: recents)
        await vm.start()
        await vm.handleRegionChange(ParkingMapTestFixtures.zoomedInRegion)
        vm.handleTap(at: ParkingMapTestFixtures.queenNorth)
        #expect(vm.lastSelectionSource == .tap)
        #expect(vm.lastFlownRegion == nil)
        #expect(vm.selection?.selected != nil)
        #expect(recents.recents.isEmpty)
        #expect(vm.sheetPrompt == .verdict)
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
