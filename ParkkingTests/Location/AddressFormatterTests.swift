import Testing
@testable import Parkking

@Suite("Address formatter and street matching")
struct AddressFormatterTests {
    @Test("strips borough names, city, province, and postal codes")
    func boroughStripping() {
        #expect(AddressFormatter.cleanAddress("551 Fairlawn Ave, North York, ON M5M 1T3, Canada") == "551 Fairlawn Ave")
        #expect(AddressFormatter.cleanAddress("12 Barse St, North York, ON") == "12 Barse St")
        #expect(AddressFormatter.cleanAddress("100 Queen St W, Toronto, ON") == "100 Queen St W")
        #expect(AddressFormatter.cleanAddress("45 Dunblaine Ave, North York") == "45 Dunblaine Ave")
        #expect(AddressFormatter.cleanAddress("77 Bloor St W, York") == "77 Bloor St W")
        #expect(AddressFormatter.cleanAddress("123 Eglinton Ave E, Scarborough, ON M1P 2K1") == "123 Eglinton Ave E")
        #expect(AddressFormatter.cleanAddress("25 The Esplanade, Old Toronto, Toronto") == "25 The Esplanade")
        #expect(AddressFormatter.cleanAddress("5000 Yonge St, North York") == "5000 Yonge St")
        #expect(AddressFormatter.cleanAddress("North York") == nil)
        #expect(AddressFormatter.cleanAddress("Toronto, ON") == nil)
        #expect(AddressFormatter.cleanAddress("York") == nil)
        #expect(AddressFormatter.cleanAddress("") == nil)
        #expect(AddressFormatter.cleanAddress(nil) == nil)
    }

    @Test("matches street names despite abbreviation differences")
    func streetNameMatching() {
        // Different streets do NOT match
        #expect(!AddressFormatter.streetNamesMatch(address: "551 Fairlawn Ave", targetStreet: "Barse St"))
        #expect(!AddressFormatter.streetNamesMatch(address: "Fairlawn Ave", targetStreet: "Barse St"))
        #expect(!AddressFormatter.streetNamesMatch(address: "100 Queen St W", targetStreet: "King St W"))
        #expect(!AddressFormatter.streetNamesMatch(address: "100 Queen St W", targetStreet: "Queen St E"))

        // Matching streets with variations
        #expect(AddressFormatter.streetNamesMatch(address: "12 Barse Street", targetStreet: "Barse St"))
        #expect(AddressFormatter.streetNamesMatch(address: "12 Barse St", targetStreet: "Barse Street"))
        #expect(AddressFormatter.streetNamesMatch(address: "Barse St", targetStreet: "Barse St"))
        #expect(AddressFormatter.streetNamesMatch(address: "100 Queen Street West", targetStreet: "Queen St W"))
        #expect(AddressFormatter.streetNamesMatch(address: "Queen St W", targetStreet: "Queen Street West"))
        #expect(AddressFormatter.streetNamesMatch(address: "Saint Clair Ave W", targetStreet: "St Clair Avenue West"))
        #expect(AddressFormatter.streetNamesMatch(address: "15 St. Clair Ave W", targetStreet: "St Clair Ave W"))
        #expect(AddressFormatter.streetNamesMatch(address: "Avenue Rd", targetStreet: "Avenue Road"))
        #expect(AddressFormatter.streetNamesMatch(address: "University Ave", targetStreet: "University Avenue"))
    }
}
