import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class BylawCopyController {
    nonisolated static let confirmationNanoseconds: UInt64 = 1_600_000_000

    private(set) var copiedKey: String?

    private let write: @MainActor (String) -> Void
    private let resetNanoseconds: UInt64
    private let announce: @MainActor (String) -> Void
    private var generation = 0

    init(
        write: @MainActor @escaping (String) -> Void = { UIPasteboard.general.string = $0 },
        resetNanoseconds: UInt64 = BylawCopyController.confirmationNanoseconds,
        announce: @MainActor @escaping (String) -> Void = { message in
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    ) {
        self.write = write
        self.resetNanoseconds = resetNanoseconds
        self.announce = announce
    }

    func copy(_ text: String, key: String) {
        write(text)
        copiedKey = key
        generation += 1
        let captured = generation
        announce("Copied")
        Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: self.resetNanoseconds)
            guard captured == self.generation else { return }
            self.copiedKey = nil
        }
    }

    func title(for key: String) -> String {
        copiedKey == key ? "Copied" : "Copy"
    }

    var isShowingConfirmation: Bool {
        copiedKey != nil
    }
}
