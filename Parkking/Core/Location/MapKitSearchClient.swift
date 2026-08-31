import Foundation
import MapKit

enum MapKitSearchError: Error, Equatable, LocalizedError {
    case outOfCoverage
    case noCoordinate
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .outOfCoverage:
            return "That place is outside Toronto parking coverage."
        case .noCoordinate:
            return "That place has no map coordinates."
        case .failed(let message):
            return message
        }
    }
}

struct PlaceCompletion: Identifiable, Equatable {
    var id: String
    var title: String
    var subtitle: String
}

struct ResolvedPlace: Equatable {
    var title: String
    var subtitle: String?
    var coordinate: CLLocationCoordinate2D

    var label: String {
        title
    }

    init(title: String, subtitle: String? = nil, coordinate: CLLocationCoordinate2D) {
        self.title = title
        self.subtitle = subtitle
        self.coordinate = coordinate
    }

    init(label: String, coordinate: CLLocationCoordinate2D) {
        self.title = label
        self.subtitle = nil
        self.coordinate = coordinate
    }

    nonisolated static func == (lhs: ResolvedPlace, rhs: ResolvedPlace) -> Bool {
        lhs.title == rhs.title
            && lhs.subtitle == rhs.subtitle
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

enum MapKitSearchConfiguration {
    nonisolated static let regionPriority = MKLocalSearchRegionPriority.required
    nonisolated static let completerResultTypes: MKLocalSearchCompleter.ResultType = [
        .address,
        .pointOfInterest,
    ]
    nonisolated static let requestResultTypes: MKLocalSearch.ResultType = [
        .address,
        .pointOfInterest,
    ]

    @MainActor
    static func apply(to completer: MKLocalSearchCompleter) {
        completer.region = ParkingMapConstants.parkingCoverageRegion
        completer.regionPriority = regionPriority
        completer.resultTypes = completerResultTypes
    }

    @MainActor
    static func apply(to request: MKLocalSearch.Request) {
        request.region = ParkingMapConstants.parkingCoverageRegion
        request.regionPriority = regionPriority
        request.resultTypes = requestResultTypes
    }

    nonisolated static func validatedCoordinate(
        _ coordinate: CLLocationCoordinate2D
    ) throws -> CLLocationCoordinate2D {
        guard ParkingMapConstants.contains(coordinate) else {
            throw MapKitSearchError.outOfCoverage
        }
        return coordinate
    }
}

@MainActor
protocol PlaceSearching: AnyObject {
    var completions: [PlaceCompletion] { get }
    var isSearching: Bool { get }
    var errorMessage: String? { get }
    func updateQuery(_ query: String)
    func resolve(_ completion: PlaceCompletion) async throws -> ResolvedPlace
}

@MainActor
@Observable
final class MapKitSearchClient: NSObject, PlaceSearching, MKLocalSearchCompleterDelegate {
    private let completer = MKLocalSearchCompleter()
    private var rawCompletions: [MKLocalSearchCompletion] = []

    private(set) var completions: [PlaceCompletion] = []
    private(set) var isSearching = false
    private(set) var errorMessage: String?

    override init() {
        super.init()
        MapKitSearchConfiguration.apply(to: completer)
        completer.delegate = self
    }

    func updateQuery(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        errorMessage = nil
        if trimmed.isEmpty {
            completer.queryFragment = ""
            rawCompletions = []
            completions = []
            isSearching = false
            return
        }
        isSearching = true
        completer.queryFragment = trimmed
    }

    func resolve(_ completion: PlaceCompletion) async throws -> ResolvedPlace {
        guard let raw = rawCompletions.first(where: {
            Self.completionID($0) == completion.id
        }) else {
            throw MapKitSearchError.failed("Place is no longer available.")
        }

        isSearching = true
        defer { isSearching = false }

        let request = MKLocalSearch.Request(completion: raw)
        MapKitSearchConfiguration.apply(to: request)
        let search = MKLocalSearch(request: request)
        let response: MKLocalSearch.Response
        do {
            response = try await search.start()
        } catch {
            throw MapKitSearchError.failed(error.localizedDescription)
        }

        guard let item = response.mapItems.first else {
            throw MapKitSearchError.noCoordinate
        }
        let coordinate = try MapKitSearchConfiguration.validatedCoordinate(item.location.coordinate)
        let title = completion.title.isEmpty
            ? (item.name ?? completion.subtitle)
            : completion.title
        let subtitle = completion.subtitle.isEmpty ? nil : completion.subtitle
        return ResolvedPlace(title: title, subtitle: subtitle, coordinate: coordinate)
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        Task { @MainActor in
            self.rawCompletions = results
            self.completions = results.map { result in
                PlaceCompletion(
                    id: Self.completionID(result),
                    title: result.title,
                    subtitle: result.subtitle
                )
            }
            self.isSearching = false
            self.errorMessage = nil
        }
    }

    nonisolated func completer(
        _ completer: MKLocalSearchCompleter,
        didFailWithError error: Error
    ) {
        Task { @MainActor in
            self.rawCompletions = []
            self.completions = []
            self.isSearching = false
            let nsError = error as NSError
            if nsError.domain == MKErrorDomain && (
                nsError.code == MKError.directionsNotFound.rawValue ||
                nsError.code == MKError.placemarkNotFound.rawValue
            ) {
                self.errorMessage = nil
            } else {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    nonisolated private static func completionID(_ completion: MKLocalSearchCompletion) -> String {
        "\(completion.title)|\(completion.subtitle)"
    }
}
