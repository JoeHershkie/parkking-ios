import Foundation

@MainActor
final class TimeQueryClock {
    private let nowProvider: () -> Date
    private var clockTask: Task<Void, Never>?
    private let onTick: @MainActor () -> Void

    init(now: @escaping () -> Date, onTick: @escaping @MainActor () -> Void) {
        self.nowProvider = now
        self.onTick = onTick
    }

    func start() {
        stop()
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let now = self.nowProvider()
                var cal = Calendar(identifier: .gregorian)
                cal.timeZone = ParkingTimeQuery.torontoTimeZone
                let seconds = cal.component(.second, from: now)
                let toNextMinute = max(1.0, Double(60 - seconds))
                let sleepSeconds = min(30.0, toNextMinute)
                try? await Task.sleep(nanoseconds: UInt64(sleepSeconds * 1_000_000_000))
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    self.onTick()
                }
            }
        }
    }

    func stop() {
        clockTask?.cancel()
        clockTask = nil
    }
}
