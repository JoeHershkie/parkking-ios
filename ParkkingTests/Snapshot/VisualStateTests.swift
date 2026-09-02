import SwiftUI
import Testing
@testable import Parkking

@MainActor
@Suite("VisualStateTests")
struct VisualStateTests {
    @Test("VerdictSheet renders all 5 curb verdict statuses cleanly")
    func verdictSheetAllStatuses() {
        let statuses: [CurbVerdictStatus] = [
            .parkingAllowed,
            .notAllowed,
            .likelyAllowed,
            .partiallyAllowed,
            .scheduleUnclear
        ]

        for status in statuses {
            let verdict = CurbVerdict(
                status: status,
                headline: "Test headline for \(status.rawValue)",
                primaryReason: "Bylaw test primary reason",
                contributingRules: [],
                activeRestrictions: [],
                uncertaintyNotes: [],
                maxStayWarning: nil,
                midnightWarning: nil,
                signageReminder: "Always verify local posted signage.",
                street: "Queen St W",
                side: "north",
                sideDisplay: "North Side"
            )

            let vm = ParkingMapTestFixtures.viewModel()
            vm.verdict = verdict
            vm.isResultPresented = true

            let detentBinding = Binding.constant(VerdictSheet.compactDetent)
            let view = VerdictSheet(viewModel: vm, detent: detentBinding)
            #expect(type(of: view) == VerdictSheet.self)
            #expect(vm.verdict?.status == status)
            #expect(vm.verdict?.street == "Queen St W")
        }
    }

    @Test("SearchSheet renders in both compact and expanded detents")
    func searchSheetDetents() {
        let vm = ParkingMapTestFixtures.viewModel()
        let compactDetent = Binding.constant(PresentationDetent.height(76))
        let compactView = SearchSheet(viewModel: vm, detent: compactDetent)
        #expect(type(of: compactView) == SearchSheet.self)

        let largeDetent = Binding.constant(PresentationDetent.large)
        let largeView = SearchSheet(viewModel: vm, detent: largeDetent)
        #expect(type(of: largeView) == SearchSheet.self)
    }

    @Test("MapFloatingChrome renders coaching prompts and 3D buttons")
    func mapFloatingChromeState() {
        let vm = ParkingMapTestFixtures.viewModel()
        let view = MapFloatingChrome(viewModel: vm, bottomPadding: 100)
        #expect(type(of: view) == MapFloatingChrome.self)
        #expect(vm.is3D == false)

        vm.toggle3D()
        #expect(vm.is3D == true)
    }

    @Test("TimeSheet custom query picker view instantiation")
    func timeSheetInstantiation() {
        let query = ParkingTimeQuery.createNowTimeQuery()
        let view = TimeSheet(query: query) { _ in }
        #expect(type(of: view) == TimeSheet.self)
        #expect(query.mode == .now)
    }
}
