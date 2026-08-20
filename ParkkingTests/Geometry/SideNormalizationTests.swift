import Testing
@testable import Parkking

@MainActor
@Suite("SideNormalization")
struct SideNormalizationTests {
    @Test("normalizes common aliases")
    func normalizesCommonAliases() {
        #expect(SideNormalization.normalizeSide("N") == "North")
        #expect(SideNormalization.normalizeSide("southbound") == "South")
        #expect(SideNormalization.normalizeSide("E/B") == "East")
    }

    @Test("formats display labels")
    func formatsDisplayLabels() {
        #expect(SideNormalization.formatSideLabel("West") == "West side")
        #expect(SideNormalization.formatSideLabel("Both") == "Both")
    }

    @Test("abbreviates sides for curb chips")
    func abbreviatesSidesForCurbChips() {
        #expect(SideNormalization.sideAbbrev("North") == "N")
        #expect(SideNormalization.sideAbbrev("southbound") == "S")
        #expect(SideNormalization.sideAbbrev("North And West") == "NW")
        #expect(SideNormalization.sideAbbrev("West, South And East") == "SEW")
    }
}
