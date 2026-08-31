import CoreLocation
import Foundation
import MapKit

final class SearchPinAnnotation: NSObject, MKAnnotation, Identifiable {
    dynamic var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    let id: String
    let source: SelectionSource

    init(
        coordinate: CLLocationCoordinate2D,
        title: String?,
        subtitle: String? = nil,
        source: SelectionSource = .search,
        id: String = UUID().uuidString
    ) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.source = source
        self.id = id
        super.init()
    }
}

final class TapDotAnnotation: NSObject, MKAnnotation, Identifiable {
    dynamic var coordinate: CLLocationCoordinate2D
    var color: UIColor
    let id: String

    init(
        coordinate: CLLocationCoordinate2D,
        color: UIColor,
        id: String = UUID().uuidString
    ) {
        self.coordinate = coordinate
        self.color = color
        self.id = id
        super.init()
    }
}
