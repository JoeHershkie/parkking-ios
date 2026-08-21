import Testing
@testable import Parkking

@MainActor
@Suite("Nearby curb sides")
struct NearbyCurbSidesTests {
    private let resolved = ParkingTimeQuery.resolveTimeQuery(
        TimeQuery(
            mode: .custom,
            date: "2025-05-20",
            startMinute: 15 * 60,
            requestedDurationMinutes: 60,
            durationPreset: .minutes(60)
        )
    )

    private let weekday = Schedule(
        status: .ok,
        source: "Mon–Fri 8am–6pm",
        windows: [
            TimeWindow(days: [1, 2, 3, 4, 5], startMinute: 480, endMinute: 1080),
        ]
    )

    @Test("groups by street, orders N/S/E/W, and colors independently")
    func groupsOrdersAndColors() {
        let north = ParkingMapTestFixtures.line(
            street: "Queen St",
            side: "N",
            coords: [[-79.4, 43.65], [-79.401, 43.65]],
            rule: "no parking north",
            id: 0,
            schedule: weekday
        )
        let south = ParkingMapTestFixtures.line(
            street: "Queen St",
            side: "South",
            coords: [[-79.4, 43.6499], [-79.401, 43.6499]],
            rule: "south sunday only",
            id: 1,
            schedule: Schedule(
                status: .ok,
                source: "Sun 8am–6pm",
                windows: [
                    TimeWindow(days: [0], startMinute: 480, endMinute: 1080),
                ]
            )
        )
        let east = ParkingMapTestFixtures.line(
            street: "Spadina Ave",
            side: "E",
            coords: [[-79.399, 43.65], [-79.399, 43.651]],
            rule: "unclear east",
            id: 2,
            schedule: Schedule(status: .failed, source: "bad")
        )

        let groups = [
            CurbSideGroup(
                groupKey: SideNormalization.curbGroupKey(street: "Queen St", side: "North"),
                street: "Queen St",
                side: "North",
                sideDisplay: "North side",
                features: [north],
                featureKeys: ["n"],
                featureIDs: [north.id],
                nearestDistanceMeters: 4
            ),
            CurbSideGroup(
                groupKey: SideNormalization.curbGroupKey(street: "Queen St", side: "South"),
                street: "Queen St",
                side: "South",
                sideDisplay: "South side",
                features: [south],
                featureKeys: ["s"],
                featureIDs: [south.id],
                nearestDistanceMeters: 8
            ),
            CurbSideGroup(
                groupKey: SideNormalization.curbGroupKey(street: "Spadina Ave", side: "East"),
                street: "Spadina Ave",
                side: "East",
                sideDisplay: "East side",
                features: [east],
                featureKeys: ["e"],
                featureIDs: [east.id],
                nearestDistanceMeters: 12
            ),
        ]

        let rows = NearbyCurbSides.streetRows(groups: groups, resolved: resolved)
        #expect(rows.map(\.street) == ["Queen St", "Spadina Ave"])
        let queen = rows[0]
        #expect(queen.sides.map(\.letter) == ["N", "S"])
        #expect(queen.sides[0].status == .notAllowed)
        #expect(queen.sides[0].tone == .notAllowed)
        #expect(queen.sides[1].tone == .allowed)
        #expect(rows[1].sides[0].letter == "E")
        #expect(rows[1].sides[0].tone == .unclear)
        #expect(queen.sides[0].accessibilityLabel(street: "Queen St") == "Queen St North side")
        #expect(queen.sides[0].accessibilityValue == "Not allowed")
    }

    @Test("selecting a side updates the view model selection")
    func selectingSideUpdatesViewModel() async {
        let vm = ParkingMapTestFixtures.viewModel()
        await vm.start()
        vm.handleTap(at: ParkingMapTestFixtures.queenNorth)
        let rows = vm.nearbyStreetRows
        #expect(rows.isEmpty == false)
        if let other = rows.flatMap(\.sides).first(where: {
            $0.groupKey != vm.selection?.selectedGroupKey
        }) {
            let previous = vm.selection?.selectedGroupKey
            vm.selectGroup(other.groupKey)
            #expect(vm.selection?.selectedGroupKey == other.groupKey)
            #expect(vm.selection?.selectedGroupKey != previous)
        }
    }
}
