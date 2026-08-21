import Foundation
import Testing
@testable import Parkking

@MainActor
@Suite("Bylaw copy")
struct BylawCopyControllerTests {
    @Test("copies text, announces Copied, and resets after the delay")
    func copiesAndResets() async {
        var pasted: String?
        var announcements: [String] = []
        let controller = BylawCopyController(
            write: { pasted = $0 },
            resetNanoseconds: 10_000_000,
            announce: { announcements.append($0) }
        )
        controller.copy("No parking 8am-6pm", key: "rule-1")
        #expect(pasted == "No parking 8am-6pm")
        #expect(controller.title(for: "rule-1") == "Copied")
        #expect(controller.isShowingConfirmation)
        #expect(announcements == ["Copied"])
        try? await Task.sleep(nanoseconds: 40_000_000)
        #expect(controller.copiedKey == nil)
        #expect(controller.title(for: "rule-1") == "Copy")
    }
}
