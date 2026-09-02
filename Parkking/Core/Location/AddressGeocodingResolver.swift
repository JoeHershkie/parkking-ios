import CoreLocation
import Foundation

@MainActor
enum AddressGeocodingResolver {
    /// Builds a list of candidate coordinates along a primary feature (nearest point, midpoint, endpoints)
    /// to improve reverse-geocoding success rates along Toronto street segments.
    static func buildCandidateCoordinates(
        nearest: CLLocationCoordinate2D,
        primaryFeature: ParkingFeature?
    ) -> [CLLocationCoordinate2D] {
        var candidates: [CLLocationCoordinate2D] = [nearest]
        guard let primaryFeature, let coords = primaryFeature.coordinateParts.first, coords.count >= 2 else {
            return candidates
        }

        let midIndex = coords.count / 2
        candidates.append(coords[midIndex])
        candidates.append(coords[0])
        candidates.append(coords[coords.count - 1])
        return candidates
    }

    /// Resolves the address for a manual curb tap by checking candidate coordinates against the target street name.
    static func resolveTapAddress(
        geocodingClient: any GeocodingProviding,
        candidateCoords: [CLLocationCoordinate2D],
        targetStreet: String,
        onResolved: @escaping @MainActor (String) -> Void
    ) -> Task<Void, Never> {
        Task {
            for candidate in candidateCoords {
                if Task.isCancelled { return }
                if let rawAddress = await geocodingClient.reverseGeocode(coordinate: candidate),
                   let cleaned = AddressFormatter.cleanAddress(rawAddress),
                   AddressFormatter.streetNamesMatch(address: cleaned, targetStreet: targetStreet) {
                    await MainActor.run {
                        onResolved(cleaned)
                    }
                    return
                }
            }
            await MainActor.run {
                onResolved(targetStreet)
            }
        }
    }

    /// Resolves the address for a coordinate search or dropped pin.
    static func resolveSearchOrGenericAddress(
        geocodingClient: any GeocodingProviding,
        coordinate: CLLocationCoordinate2D,
        targetStreet: String?,
        onResolved: @escaping @MainActor (_ address: String, _ isStreetMismatch: Bool) -> Void
    ) -> Task<Void, Never> {
        Task {
            if let rawAddress = await geocodingClient.reverseGeocode(coordinate: coordinate),
               let cleaned = AddressFormatter.cleanAddress(rawAddress) {
                let isMismatch: Bool
                if let targetStreet, !AddressFormatter.streetNamesMatch(address: cleaned, targetStreet: targetStreet) {
                    isMismatch = true
                } else {
                    isMismatch = false
                }
                await MainActor.run {
                    onResolved(cleaned, isMismatch)
                }
            }
        }
    }
}
