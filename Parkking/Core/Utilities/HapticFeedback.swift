import UIKit

@MainActor
enum HapticFeedback {
    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let selection = UISelectionFeedbackGenerator()

    static func selectionChanged() {
        selection.selectionChanged()
    }

    static func light() {
        lightImpact.impactOccurred()
    }

    static func medium() {
        mediumImpact.impactOccurred()
    }
}
