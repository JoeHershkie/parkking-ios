import CoreGraphics
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
        #expect(plan.selectedBuckets[.restricted] == [selectedRestricted.id, selectedPart.id])
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
            ParkingOverlayStyling.colorKind(severity: 1, polarity: .partial, uncertain: false)
                == .unclear
        )
        #expect(
            ParkingOverlayStyling.colorKind(severity: 1, polarity: .partial, uncertain: true)
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

    @Test("green and red base segments share the same line width; uncertain segments are thinner")
    func greenAndRedBaseLineWidth() {
        #expect(ParkingOverlayBucketKind.allowed.lineWidth == ParkingOverlayBucketKind.restricted.lineWidth)
        #expect(ParkingOverlayBucketKind.allowed.lineWidth == 5)
        #expect(ParkingOverlayBucketKind.restricted.lineWidth == 5)
        #expect(ParkingOverlayBucketKind.allowedUncertain.lineWidth == 3)
        #expect(ParkingOverlayBucketKind.restrictedUncertain.lineWidth == 3)
        #expect(ParkingOverlayBucketKind.unclearUncertain.lineWidth == 3)
        #expect(ParkingOverlayBucketKind.allowed.lineCap == .round)
        #expect(ParkingOverlayBucketKind.allowedUncertain.lineCap == .butt)
    }

    @Test("selected segment overlay styling preserves color and adds outer border")
    func selectedSegmentStyling() {
        let sampleItem = item(id: "1", polarity: .permitted, severity: 0)
        let baseOverlay = ParkingStyledOverlay(kind: .allowed, role: .base, items: [sampleItem])
        let selectedBorderOverlay = ParkingStyledOverlay(kind: .allowed, role: .selectedBorder, items: [sampleItem])
        let selectedFillOverlay = ParkingStyledOverlay(kind: .allowed, role: .selectedFill, items: [sampleItem])

        #expect(baseOverlay.lineWidth == 5)
        #expect(selectedFillOverlay.lineWidth == 8)
        #expect(selectedBorderOverlay.lineWidth == 11)

        // Fill retains the bucket kind color (green for allowed)
        #expect(selectedFillOverlay.strokeColor == ParkingOverlayBucketKind.allowed.strokeColor)
        // Border uses black
        #expect(selectedBorderOverlay.strokeColor == ParkingOverlayStyling.selectedBorderColor)
    }

    @Test("selected dashed segment overlay has matching thickness, full opacity, and butt lineCap")
    func selectedDashedSegmentStyling() {
        let sampleItem = item(id: "1", polarity: .permitted, severity: 0, uncertain: true)
        let baseOverlay = ParkingStyledOverlay(kind: .allowedUncertain, role: .base, items: [sampleItem])
        let selectedBorderOverlay = ParkingStyledOverlay(kind: .allowedUncertain, role: .selectedBorder, items: [sampleItem])
        let selectedFillOverlay = ParkingStyledOverlay(kind: .allowedUncertain, role: .selectedFill, items: [sampleItem])

        // Base is thin (3pt), but selected is full thickness (8pt fill / 11pt border)
        #expect(baseOverlay.lineWidth == 3)
        #expect(selectedFillOverlay.lineWidth == 8)
        #expect(selectedBorderOverlay.lineWidth == 11)

        // Selected lineCap is .butt so dashes don't bleed into gaps
        #expect(selectedFillOverlay.lineCap == .butt)
        #expect(selectedBorderOverlay.lineCap == .butt)

        // Selected colors are fully opaque
        #expect(selectedFillOverlay.strokeColor == ParkingOverlayBucketKind.allowedUncertain.strokeColor)
        #expect(selectedBorderOverlay.strokeColor == ParkingOverlayStyling.selectedBorderColor)
    }

    @Test("satellite line width calibration scales down base and selected lines for 3D terrain rendering")
    func satelliteLineWidthCalibration() {
        #expect(ParkingOverlayBucketKind.allowed.lineWidth(isSatellite: true) == 3.5)
        #expect(ParkingOverlayBucketKind.allowedUncertain.lineWidth(isSatellite: true) == 2.5)
        #expect(ParkingOverlayStyling.selectedLineWidth(isSatellite: true) == 5.5)
        #expect(ParkingOverlayStyling.selectedBorderWidth(isSatellite: true) == 8.0)

        let sampleItem = item(id: "1", polarity: .permitted, severity: 0)
        let satelliteOverlay = ParkingStyledOverlay(kind: .allowed, role: .base, isSatellite: true, items: [sampleItem])
        #expect(satelliteOverlay.lineWidth == 3.5)
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
