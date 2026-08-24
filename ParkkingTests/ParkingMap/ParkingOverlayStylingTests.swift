import CoreLocation
import Testing
@testable import Parkking

@Suite("Parking overlay styling")
struct ParkingOverlayStylingTests {
    @Test("groups mixed polarity and keeps selected IDs in color buckets")
    func groupsAndKeepsSelectionInColorBuckets() {
        let allowed = item(id: "1", polarity: .permitted, severity: 0)
        let unclear = item(id: "2", polarity: .unknown, severity: 1)
        let restricted = item(id: "3", polarity: .restricted, severity: 2)
        let uncertainAllowed = item(
            id: "4",
            polarity: .inactive,
            severity: 0,
            uncertain: true
        )
        let selectedRestricted = item(id: "5", polarity: .notPermitted, severity: 2)
        let selectedPart = item(
            id: "5",
            partIndex: 1,
            polarity: .notPermitted,
            severity: 2
        )

        let plan = ParkingOverlayStyling.plan(
            items: [allowed, unclear, restricted, uncertainAllowed, selectedRestricted, selectedPart],
            selectedFeatureIDs: ["5"]
        )

        #expect(plan.colorBuckets[.allowed] == [allowed.id])
        #expect(plan.colorBuckets[.unclear] == [unclear.id])
        #expect(plan.colorBuckets[.restricted] == [restricted.id, selectedRestricted.id, selectedPart.id])
        #expect(plan.colorBuckets[.allowedUncertain] == [uncertainAllowed.id])
        #expect(plan.colorBuckets[.restrictedUncertain] == nil)
        #expect(plan.selectedIDs == [selectedRestricted.id, selectedPart.id])
        #expect(plan.colorBuckets.values.flatMap { $0 }.contains(selectedRestricted.id))
        #expect(plan.colorBuckets.values.flatMap { $0 }.contains(selectedPart.id))
    }

    @Test("maps polarity and uncertain flag onto the six color kinds")
    func colorKindMapping() {
        #expect(
            ParkingOverlayStyling.colorKind(severity: 0, polarity: .permitted, uncertain: false)
                == .allowed
        )
        #expect(
            ParkingOverlayStyling.colorKind(severity: 0, polarity: .inactive, uncertain: true)
                == .allowedUncertain
        )
        #expect(
            ParkingOverlayStyling.colorKind(severity: 1, polarity: .unknown, uncertain: false)
                == .unclear
        )
        #expect(
            ParkingOverlayStyling.colorKind(severity: 1, polarity: .unknown, uncertain: true)
                == .unclearUncertain
        )
        #expect(
            ParkingOverlayStyling.colorKind(severity: 2, polarity: .restricted, uncertain: false)
                == .restricted
        )
        #expect(
            ParkingOverlayStyling.colorKind(severity: 2, polarity: .notPermitted, uncertain: true)
                == .restrictedUncertain
        )
    }

    private func item(
        id: String,
        partIndex: Int = 0,
        polarity: FilterPolarity,
        severity: Int,
        uncertain: Bool = false
    ) -> ParkingMapRenderItem {
        ParkingMapRenderItem(
            featureID: FeatureID(id),
            partIndex: partIndex,
            coordinates: [
                CLLocationCoordinate2D(latitude: 43.65, longitude: -79.38),
                CLLocationCoordinate2D(latitude: 43.651, longitude: -79.381),
            ],
            severity: severity,
            polarity: polarity,
            isSelected: false,
            isUncertainPlacement: uncertain
        )
    }
}
