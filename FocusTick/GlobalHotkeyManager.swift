import Cocoa

/// Registers a system-wide CGEventTap for ⌃\ (Control + Backslash).
///
/// Requires Accessibility permission:
///   System Settings → Privacy & Security → Accessibility → add your app.
///
/// If the tap cannot be created (permission denied), the app still works
/// through the menu — it just won't respond to the hotkey.
final class GlobalHotkeyManager {

    // Key code 42 = backslash (\) on a standard US keyboard layout.
    // Override `targetKeyCode` if you use a non-US keyboard.
    var targetKeyCode: Int64 = 42

    private let action: () -> Void
    private var eventTap: CFMachPort?

    // MARK: - Init

    init(action: @escaping () -> Void) {
        self.action = action
    }

    // MARK: - Registration

    func register() {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)

        let selfPtr = Unmanaged.passRetained(self).toOpaque()

        let callback: CGEventTapCallBack = { _, _, event, refcon -> Unmanaged<CGEvent>? in
            guard let refcon else { return Unmanaged.passRetained(event) }
            let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(refcon).takeUnretainedValue()

            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags   = event.flags

            // ✅ Control only (no other modifiers)
            let controlOnly = flags.contains(.maskControl)
                           && !flags.contains(.maskShift)
                           && !flags.contains(.maskAlternate)
                           && !flags.contains(.maskCommand)

            if keyCode == manager.targetKeyCode && controlOnly {
                manager.action()
                return nil   // consume event
            }

            return Unmanaged.passRetained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: selfPtr
        ) else {
            Unmanaged<GlobalHotkeyManager>.fromOpaque(selfPtr).release()
            showAccessibilityAlert()
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    // MARK: - Teardown

    deinit {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
    }

    // MARK: - Helpers

    private func showAccessibilityAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = """
                FocusTick needs Accessibility access to register the global ⌃\\ hotkey.

                Go to:
                System Settings → Privacy & Security → Accessibility
                then add and enable FocusTick.

                The menu bar item still works without this permission.
                """
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Dismiss")

            if alert.runModal() == .alertFirstButtonReturn {
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                NSWorkspace.shared.open(url)
            }
        }
    }
}
