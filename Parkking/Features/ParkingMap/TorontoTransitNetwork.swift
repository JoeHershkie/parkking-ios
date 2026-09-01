import CoreLocation
import Foundation
import MapKit
import UIKit

final class TransitLineOverlay: MKMultiPolyline {
    let name: String
    let strokeColor: UIColor
    let lineWidth: CGFloat

    init(coordinates: [CLLocationCoordinate2D], name: String, color: UIColor, width: CGFloat = 4.5) {
        self.name = name
        self.strokeColor = color
        self.lineWidth = width
        var coords = coordinates
        let polyline = MKPolyline(coordinates: &coords, count: coords.count)
        super.init([polyline])
    }
}

enum TorontoTransitNetwork {
    static func makeOverlays() -> [TransitLineOverlay] {
        let line1Color = UIColor(red: 0.98, green: 0.77, blue: 0.05, alpha: 0.95) // Yellow
        let line2Color = UIColor(red: 0.0, green: 0.58, blue: 0.27, alpha: 0.95)  // Green
        let line4Color = UIColor(red: 0.65, green: 0.12, blue: 0.38, alpha: 0.95) // Purple
        let line5Color = UIColor(red: 0.96, green: 0.47, blue: 0.13, alpha: 0.95) // Orange
        let upExpressColor = UIColor(red: 0.0, green: 0.52, blue: 0.80, alpha: 0.9) // Blue/Teal

        let line1Coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 43.7941, longitude: -79.5276), // Vaughan
            CLLocationCoordinate2D(latitude: 43.7839, longitude: -79.5233), // Hwy 407
            CLLocationCoordinate2D(latitude: 43.7769, longitude: -79.5097), // Pioneer Village
            CLLocationCoordinate2D(latitude: 43.7741, longitude: -79.4997), // York Univ
            CLLocationCoordinate2D(latitude: 43.7653, longitude: -79.4911), // Finch West
            CLLocationCoordinate2D(latitude: 43.7533, longitude: -79.4783), // Downsview Park
            CLLocationCoordinate2D(latitude: 43.7496, longitude: -79.4623), // Sheppard West
            CLLocationCoordinate2D(latitude: 43.7342, longitude: -79.4501), // Wilson
            CLLocationCoordinate2D(latitude: 43.7250, longitude: -79.4475), // Yorkdale
            CLLocationCoordinate2D(latitude: 43.7156, longitude: -79.4440), // Lawrence West
            CLLocationCoordinate2D(latitude: 43.7088, longitude: -79.4408), // Glencairn
            CLLocationCoordinate2D(latitude: 43.6992, longitude: -79.4358), // Cedarvale / Eglinton West
            CLLocationCoordinate2D(latitude: 43.6838, longitude: -79.4151), // St Clair West
            CLLocationCoordinate2D(latitude: 43.6745, longitude: -79.4069), // Dupont
            CLLocationCoordinate2D(latitude: 43.6672, longitude: -79.4042), // Spadina
            CLLocationCoordinate2D(latitude: 43.6682, longitude: -79.3999), // St George
            CLLocationCoordinate2D(latitude: 43.6629, longitude: -79.3926), // Museum
            CLLocationCoordinate2D(latitude: 43.6599, longitude: -79.3906), // Queen's Park
            CLLocationCoordinate2D(latitude: 43.6548, longitude: -79.3883), // St Patrick
            CLLocationCoordinate2D(latitude: 43.6503, longitude: -79.3867), // Osgoode
            CLLocationCoordinate2D(latitude: 43.6476, longitude: -79.3848), // St Andrew
            CLLocationCoordinate2D(latitude: 43.6456, longitude: -79.3806), // Union
            CLLocationCoordinate2D(latitude: 43.6491, longitude: -79.3778), // King
            CLLocationCoordinate2D(latitude: 43.6524, longitude: -79.3792), // Queen
            CLLocationCoordinate2D(latitude: 43.6565, longitude: -79.3810), // Dundas
            CLLocationCoordinate2D(latitude: 43.6613, longitude: -79.3831), // College
            CLLocationCoordinate2D(latitude: 43.6654, longitude: -79.3840), // Wellesley
            CLLocationCoordinate2D(latitude: 43.6709, longitude: -79.3857), // Bloor-Yonge
            CLLocationCoordinate2D(latitude: 43.6769, longitude: -79.3888), // Rosedale
            CLLocationCoordinate2D(latitude: 43.6823, longitude: -79.3908), // Summerhill
            CLLocationCoordinate2D(latitude: 43.6882, longitude: -79.3933), // St Clair
            CLLocationCoordinate2D(latitude: 43.6978, longitude: -79.3972), // Davisville
            CLLocationCoordinate2D(latitude: 43.7064, longitude: -79.3986), // Eglinton
            CLLocationCoordinate2D(latitude: 43.7252, longitude: -79.4022), // Lawrence
            CLLocationCoordinate2D(latitude: 43.7439, longitude: -79.4067), // York Mills
            CLLocationCoordinate2D(latitude: 43.7615, longitude: -79.4109), // Sheppard-Yonge
            CLLocationCoordinate2D(latitude: 43.7688, longitude: -79.4128), // North York Centre
            CLLocationCoordinate2D(latitude: 43.7807, longitude: -79.4147), // Finch
        ]

        let line2Coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 43.6376, longitude: -79.5356), // Kipling
            CLLocationCoordinate2D(latitude: 43.6453, longitude: -79.5244), // Islington
            CLLocationCoordinate2D(latitude: 43.6481, longitude: -79.5113), // Royal York
            CLLocationCoordinate2D(latitude: 43.6498, longitude: -79.4943), // Old Mill
            CLLocationCoordinate2D(latitude: 43.6500, longitude: -79.4839), // Jane
            CLLocationCoordinate2D(latitude: 43.6517, longitude: -79.4759), // Runnymede
            CLLocationCoordinate2D(latitude: 43.6538, longitude: -79.4670), // High Park
            CLLocationCoordinate2D(latitude: 43.6555, longitude: -79.4597), // Keele
            CLLocationCoordinate2D(latitude: 43.6569, longitude: -79.4528), // Dundas West
            CLLocationCoordinate2D(latitude: 43.6590, longitude: -79.4428), // Lansdowne
            CLLocationCoordinate2D(latitude: 43.6602, longitude: -79.4357), // Dufferin
            CLLocationCoordinate2D(latitude: 43.6624, longitude: -79.4262), // Ossington
            CLLocationCoordinate2D(latitude: 43.6641, longitude: -79.4184), // Christie
            CLLocationCoordinate2D(latitude: 43.6659, longitude: -79.4111), // Bathurst
            CLLocationCoordinate2D(latitude: 43.6672, longitude: -79.4042), // Spadina
            CLLocationCoordinate2D(latitude: 43.6682, longitude: -79.3999), // St George
            CLLocationCoordinate2D(latitude: 43.6702, longitude: -79.3900), // Bay
            CLLocationCoordinate2D(latitude: 43.6709, longitude: -79.3857), // Bloor-Yonge
            CLLocationCoordinate2D(latitude: 43.6722, longitude: -79.3764), // Sherbourne
            CLLocationCoordinate2D(latitude: 43.6738, longitude: -79.3687), // Castle Frank
            CLLocationCoordinate2D(latitude: 43.6770, longitude: -79.3584), // Broadview
            CLLocationCoordinate2D(latitude: 43.6782, longitude: -79.3522), // Chester
            CLLocationCoordinate2D(latitude: 43.6799, longitude: -79.3450), // Pape
            CLLocationCoordinate2D(latitude: 43.6811, longitude: -79.3378), // Donlands
            CLLocationCoordinate2D(latitude: 43.6826, longitude: -79.3304), // Greenwood
            CLLocationCoordinate2D(latitude: 43.6842, longitude: -79.3231), // Coxwell
            CLLocationCoordinate2D(latitude: 43.6864, longitude: -79.3129), // Woodbine
            CLLocationCoordinate2D(latitude: 43.6890, longitude: -79.3017), // Main St
            CLLocationCoordinate2D(latitude: 43.6948, longitude: -79.2887), // Victoria Park
            CLLocationCoordinate2D(latitude: 43.7114, longitude: -79.2792), // Warden
            CLLocationCoordinate2D(latitude: 43.7325, longitude: -79.2638), // Kennedy
        ]

        let line4Coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 43.7615, longitude: -79.4109), // Sheppard-Yonge
            CLLocationCoordinate2D(latitude: 43.7669, longitude: -79.3867), // Bayview
            CLLocationCoordinate2D(latitude: 43.7692, longitude: -79.3763), // Bessarion
            CLLocationCoordinate2D(latitude: 43.7712, longitude: -79.3657), // Leslie
            CLLocationCoordinate2D(latitude: 43.7754, longitude: -79.3464), // Don Mills
        ]

        let line5Coords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 43.6885, longitude: -79.4862), // Mount Dennis
            CLLocationCoordinate2D(latitude: 43.6896, longitude: -79.4704), // Keelesdale
            CLLocationCoordinate2D(latitude: 43.6922, longitude: -79.4526), // Caledonia
            CLLocationCoordinate2D(latitude: 43.6953, longitude: -79.4447), // Fairbank
            CLLocationCoordinate2D(latitude: 43.6974, longitude: -79.4398), // Oakwood
            CLLocationCoordinate2D(latitude: 43.6992, longitude: -79.4358), // Cedarvale
            CLLocationCoordinate2D(latitude: 43.7022, longitude: -79.4215), // Forest Hill
            CLLocationCoordinate2D(latitude: 43.7038, longitude: -79.4106), // Chaplin
            CLLocationCoordinate2D(latitude: 43.7051, longitude: -79.4056), // Avenue
            CLLocationCoordinate2D(latitude: 43.7064, longitude: -79.3986), // Eglinton
            CLLocationCoordinate2D(latitude: 43.7082, longitude: -79.3900), // Mount Pleasant
            CLLocationCoordinate2D(latitude: 43.7107, longitude: -79.3773), // Leaside
            CLLocationCoordinate2D(latitude: 43.7131, longitude: -79.3648), // Laird
            CLLocationCoordinate2D(latitude: 43.7176, longitude: -79.3516), // Sunnybrook Park
            CLLocationCoordinate2D(latitude: 43.7208, longitude: -79.3392), // Science Centre
            CLLocationCoordinate2D(latitude: 43.7225, longitude: -79.3317), // Aga Khan
            CLLocationCoordinate2D(latitude: 43.7242, longitude: -79.3248), // Wynford
            CLLocationCoordinate2D(latitude: 43.7258, longitude: -79.3142), // Sloane
            CLLocationCoordinate2D(latitude: 43.7275, longitude: -79.3036), // O'Connor
            CLLocationCoordinate2D(latitude: 43.7291, longitude: -79.2929), // Pharmacy
            CLLocationCoordinate2D(latitude: 43.7303, longitude: -79.2842), // Hakimi
            CLLocationCoordinate2D(latitude: 43.7311, longitude: -79.2783), // Golden Mile
            CLLocationCoordinate2D(latitude: 43.7317, longitude: -79.2721), // Birchmount
            CLLocationCoordinate2D(latitude: 43.7321, longitude: -79.2668), // Ionview
            CLLocationCoordinate2D(latitude: 43.7325, longitude: -79.2638), // Kennedy
        ]

        let upExpressCoords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 43.6456, longitude: -79.3806), // Union
            CLLocationCoordinate2D(latitude: 43.6569, longitude: -79.4528), // Bloor
            CLLocationCoordinate2D(latitude: 43.7001, longitude: -79.5147), // Weston
            CLLocationCoordinate2D(latitude: 43.6841, longitude: -79.6083), // Pearson Airport
        ]

        return [
            TransitLineOverlay(coordinates: line1Coords, name: "Line 1 (Yonge-University)", color: line1Color),
            TransitLineOverlay(coordinates: line2Coords, name: "Line 2 (Bloor-Danforth)", color: line2Color),
            TransitLineOverlay(coordinates: line4Coords, name: "Line 4 (Sheppard)", color: line4Color),
            TransitLineOverlay(coordinates: line5Coords, name: "Line 5 (Eglinton)", color: line5Color),
            TransitLineOverlay(coordinates: upExpressCoords, name: "UP Express", color: upExpressColor, width: 4.0),
        ]
    }
}
