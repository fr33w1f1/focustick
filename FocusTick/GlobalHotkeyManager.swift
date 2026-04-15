import Cocoa

/// Registers a system-wide CGEventTap for ⌃\ (Control + Backslash).
///
/// Requires Accessibility permission:
///   System Settings → Privacy & Security → Accessibility → add your app.
final class GlobalHotkeyManager {

    // Key code 42 = backslash (\) on a US keyboard.
    var targetKeyCode: Int64 = 42

    private let action: () -> Void
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(action: @escaping () -> Void) {
        self.action = action
    }

    func register() {
        print("GlobalHotkeyManager: Attempting to register hotkey (KeyCode: \(targetKeyCode))...")
        
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let isTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        print("GlobalHotkeyManager: Is process trusted for Accessibility? \(isTrusted)")

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        
        // We pass 'self' as an unretained pointer because the AppDelegate owns us.
        // If we wanted to be safer, we could pass a retained pointer and release it in deinit.
        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        guard let tap = CGEvent.tapCreate(
            tap: .cgAnnotatedSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: GlobalHotkeyManager.eventCallback,
            userInfo: selfPtr
        ) else {
            print("GlobalHotkeyManager: FAILED to create event tap. Check Accessibility permissions.")
            showAccessibilityAlert()
            return
        }

        if !CGEvent.tapIsEnabled(tap: tap) {
            print("GlobalHotkeyManager: Tap was created but is NOT enabled. This usually means the app isn't trusted.")
        }

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        
        print("GlobalHotkeyManager: Event tap registered and enabled.")
    }

    private static let eventCallback: CGEventTapCallBack = { _, type, event, refcon -> Unmanaged<CGEvent>? in
        guard let refcon = refcon else {
            return Unmanaged.passRetained(event)
        }
        
        let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
        
        if type == .keyDown {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags
            
            // Mask for the modifiers we care about
            let relevantModifiers: CGEventFlags = [.maskControl, .maskShift, .maskAlternate, .maskCommand]
            let currentModifiers = flags.intersection(relevantModifiers)
            
            // Helpful for debugging: uncomment to see every keypress
            // print("GlobalHotkeyManager: Key \(keyCode), Flags 0x\(String(flags.rawValue, radix: 16)), Modifiers 0x\(String(currentModifiers.rawValue, radix: 16))")

            // Check for EXACTLY Control
            if keyCode == manager.targetKeyCode && currentModifiers == .maskControl {
                print("GlobalHotkeyManager: ⌃\\ detected! Triggering action.")
                
                // Execute action on the main thread to be safe
                DispatchQueue.main.async {
                    manager.action()
                }
                
                // Return nil to consume the event so other apps don't see it
                return nil
            }
        }
        
        return Unmanaged.passRetained(event)
    }

    deinit {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        print("GlobalHotkeyManager: Deinitialized.")
    }

    private func showAccessibilityAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = """
                FocusTick needs Accessibility access to register the global ⌃\\ hotkey.

                Go to:
                System Settings → Privacy & Security → Accessibility
                then add and enable FocusTick.
                """
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Dismiss")

            if alert.runModal() == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}
