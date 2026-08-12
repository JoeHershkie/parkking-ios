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
        let fixtures = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/schedule_corpus.json")
        let data = try Data(contentsOf: fixtures)
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
