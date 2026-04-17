import Foundation
import CoreGraphics

/// Monitors system-wide idle time (keyboard/mouse) and triggers a callback if it exceeds a threshold.
final class IdleManager {

    private var timer: Timer?
    var threshold: TimeInterval
    private let onIdleTimeout: () -> Void
    private var isMonitoring: Bool = false

    /// - Parameters:
    ///   - threshold: Idle timeout in seconds.
    ///   - onIdleTimeout: Callback triggered when idle time exceeds threshold.
    init(threshold: TimeInterval, onIdleTimeout: @escaping () -> Void) {
        self.threshold = threshold
        self.onIdleTimeout = onIdleTimeout
    }

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        // Check every 5 seconds to be efficient
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkIdleTime()
        }
    }

    func stopMonitoring() {
        isMonitoring = false
        timer?.invalidate()
        timer = nil
    }

    private func checkIdleTime() {
        guard threshold > 0 else { return }
        let idleSeconds = CGEventSource.secondsSinceLastEventType(.combinedSessionState, .null)
        if idleSeconds >= threshold {
            print("IdleManager: Idle timeout reached (\(idleSeconds)s >= \(threshold)s).")
            DispatchQueue.main.async { [weak self] in
                self?.onIdleTimeout()
            }
        }
    }
}
