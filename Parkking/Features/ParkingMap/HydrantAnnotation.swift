import CoreLocation
import Foundation
import MapKit
import UIKit

final class HydrantAnnotation: NSObject, MKAnnotation, Identifiable, @unchecked Sendable {
    dynamic var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    let id: String
    let featureID: String

    nonisolated init(
        coordinate: CLLocationCoordinate2D,
        featureID: String,
        id: String = UUID().uuidString
    ) {
        self.coordinate = coordinate
        self.featureID = featureID
        self.id = id
        self.title = "Fire Hydrant"
        self.subtitle = "3m setback in effect"
        super.init()
    }
}

final class HydrantAnnotationView: MKAnnotationView {
    static let reuseID = "HydrantAnnotationView"
    private let iconView = UIImageView()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupView()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }

    private func setupView() {
        frame = CGRect(x: 0, y: 0, width: 20, height: 20)
        centerOffset = CGPoint(x: 0, y: 0)
        backgroundColor = .clear

        let bgView = UIView(frame: bounds)
        bgView.backgroundColor = UIColor.systemRed
        bgView.layer.cornerRadius = 10
        bgView.layer.borderWidth = 1.5
        bgView.layer.borderColor = UIColor.white.cgColor
        bgView.layer.shadowColor = UIColor.black.cgColor
        bgView.layer.shadowOpacity = 0.3
        bgView.layer.shadowRadius = 2
        bgView.layer.shadowOffset = CGSize(width: 0, height: 1)
        bgView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(bgView)

        let config = UIImage.SymbolConfiguration(pointSize: 10, weight: .bold)
        iconView.image = UIImage(systemName: "flame.fill", withConfiguration: config)
        iconView.tintColor = .white
        iconView.contentMode = .center
        iconView.frame = bounds
        iconView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(iconView)

        displayPriority = .defaultLow
        canShowCallout = true
    }
}
