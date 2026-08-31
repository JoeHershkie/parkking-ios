import Foundation
import Testing
@testable import Parkking

@Suite("Schedule corpus")
struct ScheduleCorpusTests {
    struct Corpus: Decodable {
        var version: Int
        var cases: [Case]

        struct Case: Decodable {
            var id: String
            var schedule: Schedule
            var slot: Slot
            var expected: Bool
        }
    }

    @Test func sharedCorpusMembershipParity() throws {
        let bundleURL = Bundle(for: BundleToken.self).url(
            forResource: "schedule_corpus",
            withExtension: "json",
            subdirectory: "Fixtures"
        ) ?? Bundle(for: BundleToken.self).url(
            forResource: "schedule_corpus",
            withExtension: "json"
        )
        let filePathURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/schedule_corpus.json")

        guard let fixtureURL = bundleURL ?? (FileManager.default.fileExists(atPath: filePathURL.path) ? filePathURL : nil) else {
            Issue.record("schedule_corpus.json not found in test bundle or filePath")
            return
        }

        let data = try Data(contentsOf: fixtureURL)
        let corpus = try JSONDecoder().decode(Corpus.self, from: data)
        #expect(corpus.cases.count == 23)

        for testCase in corpus.cases {
            let actual = ScheduleMembership.overlapsMembership(
                testCase.schedule,
                slot: testCase.slot
            )
            #expect(
                actual == testCase.expected,
                "Case \(testCase.id): expected \(testCase.expected), got \(actual)"
            )
        }
    }
}

private final class BundleToken {}
