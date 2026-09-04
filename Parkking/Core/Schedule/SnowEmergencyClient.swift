import Foundation
import Observation

/// Status of an official City of Toronto Major Snow Storm Condition.
/// Under Toronto Municipal Code Chapter 950-406, declarations remain in effect
/// for 72 hours unless terminated earlier or extended by the General Manager.
struct SnowEmergencyStatus: Sendable, Equatable, Codable {
    var isDeclared: Bool
    var declaredAt: Date?
    var expiresAt: Date?
    var sourceURL: String?

    nonisolated static let inactive = SnowEmergencyStatus(isDeclared: false)
}

protocol SnowEmergencyProviding: Sendable {
    func currentStatus() async -> SnowEmergencyStatus
}

@MainActor
@Observable
final class SnowEmergencyClient: SnowEmergencyProviding {
    var status: SnowEmergencyStatus = .inactive

    var isDeclared: Bool {
        status.isDeclared
    }

    init(initialStatus: SnowEmergencyStatus = SnowEmergencyStatus(isDeclared: false)) {
        self.status = initialStatus
    }

    func currentStatus() async -> SnowEmergencyStatus {
        status
    }

    func setDeclared(_ active: Bool, declaredAt: Date? = nil, expiresAt: Date? = nil) {
        if active {
            let start = declaredAt ?? Date()
            let end = expiresAt ?? start.addingTimeInterval(72 * 3600)
            status = SnowEmergencyStatus(
                isDeclared: true,
                declaredAt: start,
                expiresAt: end,
                sourceURL: "https://www.toronto.ca/services-payments/streets-parking-transportation/road-maintenance/winter-maintenance/"
            )
        } else {
            status = .inactive
        }
    }

    func toggle() {
        setDeclared(!isDeclared)
    }
}
