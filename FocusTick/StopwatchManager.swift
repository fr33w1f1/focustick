import Foundation

/// Thread-safe stopwatch that fires its callback on a private serial queue.
/// The caller is responsible for dispatching UI updates to the main thread.
final class StopwatchManager {

    // MARK: - State

    enum State { case idle, running, stopped }

    private(set) var state: State = .idle

    // MARK: - Private

    private var elapsedSeconds: Int = 0
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "dev.focustick.timer", qos: .userInteractive)
    private let onUpdate: (_ timeString: String, _ isRunning: Bool) -> Void

    // MARK: - Init

    init(onUpdate: @escaping (_ timeString: String, _ isRunning: Bool) -> Void) {
        self.onUpdate = onUpdate
        // Publish the initial "00:00" state immediately
        onUpdate(formatted(0), false)
    }

    // MARK: - Public API

    func toggle() {
        switch state {
        case .idle, .stopped: start()
        case .running:        stop()
        }
    }

    func start() {
        guard state != .running else { return }
        state = .running

        let t = DispatchSource.makeTimerSource(queue: queue)
        // Fire 1 s after now, repeat every second with tight leeway for accuracy
        t.schedule(deadline: .now() + 1, repeating: 1.0, leeway: .milliseconds(10))
        t.setEventHandler { [weak self] in
            guard let self else { return }
            self.elapsedSeconds += 1
            self.onUpdate(self.formatted(self.elapsedSeconds), true)
        }
        t.resume()
        timer = t

        // Publish immediately so the bullet appears without waiting 1 s
        onUpdate(formatted(elapsedSeconds), true)
    }

    func stop() {
        guard state == .running else { return }
        state = .stopped
        cancelTimer()
        onUpdate(formatted(elapsedSeconds), false)
    }

    func reset() {
        cancelTimer()
        elapsedSeconds = 0
        state = .idle
        onUpdate(formatted(0), false)
    }

    // MARK: - Helpers

    private func cancelTimer() {
        timer?.cancel()
        timer = nil
    }

    private func formatted(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%02d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }
}
