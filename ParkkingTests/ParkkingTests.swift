import Testing
@testable import Parkking

@MainActor
@Suite("Parkking smoke")
struct ParkkingTests {
    @Test("domain types are constructible")
    func smoke() {
        let slot = Slot(dayOfWeek: 2, minuteOfDay: 900, month: 5, dayOfMonth: 20, year: 2025)
        #expect(slot.year == 2025)
        #expect(ParkingTimeQuery.midnightMinute == 1439)
    }
}
