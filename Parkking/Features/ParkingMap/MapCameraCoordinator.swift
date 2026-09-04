import CoreLocation
import Foundation
import MapKit
import Observation
import UIKit

@MainActor
@Observable
final class MapCameraCoordinator {
    static let mapStyleStorageKey = "parkking.mapStyle"
    static let cameraCenterLatKey = "parkking.camera.centerLat"
    static let cameraCenterLngKey = "parkking.camera.centerLng"
    static let cameraSpanLatKey = "parkking.camera.spanLat"
    static let cameraSpanLngKey = "parkking.camera.spanLng"

    var is3D = false
    var pendingCameraPitch: CGFloat?
    var pendingCameraRegion: MKCoordinateRegion?
    var visibleRegion: MKCoordinateRegion?
    private(set) var lastFlownRegion: MKCoordinateRegion?
    var mapStyle: MapViewStyle = .driving

    init(mapStyle: MapViewStyle? = nil, initialRegion: MKCoordinateRegion? = nil) {
        if let mapStyle {
            self.mapStyle = mapStyle
        } else if let saved = UserDefaults.standard.string(forKey: Self.mapStyleStorageKey),
                  let resolved = MapViewStyle(rawValue: saved) {
            self.mapStyle = resolved
        } else {
            self.mapStyle = .driving
        }

        if let initialRegion {
            self.pendingCameraRegion = initialRegion
            self.visibleRegion = initialRegion
        } else if let restored = Self.restoreSavedRegion() {
            self.pendingCameraRegion = restored
            self.visibleRegion = restored
        }
    }

    func setMapStyle(_ style: MapViewStyle) {
        guard self.mapStyle != style else { return }
        self.mapStyle = style
        UserDefaults.standard.set(style.rawValue, forKey: Self.mapStyleStorageKey)
        HapticFeedback.selectionChanged()
    }

    func toggle3D() {
        HapticFeedback.light()
        if is3D {
            is3D = false
            pendingCameraPitch = 0
        } else {
            is3D = true
            pendingCameraPitch = 55
        }
    }

    func updatePitch(_ pitch: CGFloat) {
        let now3D = pitch > 20
        if is3D != now3D {
            is3D = now3D
        }
    }

    func flyTo(region: MKCoordinateRegion) {
        pendingCameraRegion = region
        lastFlownRegion = region
        visibleRegion = region
        saveRegion(region)
    }

    func recenterToronto() {
        HapticFeedback.light()
        flyTo(region: ParkingMapConstants.neighborhoodRegion(around: ParkingMapConstants.torontoCenter))
    }

    static var isRunningInTest: Bool {
        NSClassFromString("XCTestCase") != nil || ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil
    }

    func saveRegion(_ region: MKCoordinateRegion) {
        guard !Self.isRunningInTest else { return }
        UserDefaults.standard.set(region.center.latitude, forKey: Self.cameraCenterLatKey)
        UserDefaults.standard.set(region.center.longitude, forKey: Self.cameraCenterLngKey)
        UserDefaults.standard.set(region.span.latitudeDelta, forKey: Self.cameraSpanLatKey)
        UserDefaults.standard.set(region.span.longitudeDelta, forKey: Self.cameraSpanLngKey)
    }

    static func restoreSavedRegion() -> MKCoordinateRegion? {
        guard !isRunningInTest else { return nil }
        let lat = UserDefaults.standard.double(forKey: Self.cameraCenterLatKey)
        let lng = UserDefaults.standard.double(forKey: Self.cameraCenterLngKey)
        let spanLat = UserDefaults.standard.double(forKey: Self.cameraSpanLatKey)
        let spanLng = UserDefaults.standard.double(forKey: Self.cameraSpanLngKey)

        guard lat != 0, lng != 0, spanLat > 0, spanLng > 0 else { return nil }
        let coord = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        guard ParkingMapConstants.contains(coord) else { return nil }

        return MKCoordinateRegion(
            center: coord,
            span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLng)
        )
    }
}
