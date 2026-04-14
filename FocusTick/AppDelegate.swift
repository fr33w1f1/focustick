import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var statusItem: NSStatusItem!
    private var stopwatch: StopwatchManager!
    private var hotkey: GlobalHotkeyManager!

    private var startStopMenuItem: NSMenuItem!
    private var resetMenuItem: NSMenuItem!

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as a background agent — no Dock icon, no app switcher entry
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        setupMenu()

        stopwatch = StopwatchManager { [weak self] timeString, isRunning in
            self?.updateDisplay(timeString: timeString, isRunning: isRunning)
        }

        hotkey = GlobalHotkeyManager { [weak self] in
            self?.stopwatch.toggle()
        }
        hotkey.register()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.title = "00:00"
        // Monospaced digits prevent the bar item from jumping in width each second
        button.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
    }

    // MARK: - Menu

    private func setupMenu() {
        let menu = NSMenu()

        startStopMenuItem = NSMenuItem(
            title: "Start",
            action: #selector(toggleTimer),
            keyEquivalent: ""
        )
        startStopMenuItem.target = self
        menu.addItem(startStopMenuItem)

        resetMenuItem = NSMenuItem(
            title: "Reset",
            action: #selector(resetTimer),
            keyEquivalent: ""
        )
        resetMenuItem.target = self
        menu.addItem(resetMenuItem)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit FocusTick",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quit)

        statusItem.menu = menu
    }

    // MARK: - Display Update

    private func updateDisplay(timeString: String, isRunning: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let label = isRunning ? "● \(timeString)" : timeString
            self.statusItem.button?.title = label
            self.startStopMenuItem.title = isRunning ? "Stop" : "Start"
            // Dim the Reset item when idle / already at zero
            self.resetMenuItem.isEnabled = (timeString != "00:00")
        }
    }

    // MARK: - Actions

    @objc private func toggleTimer() {
        stopwatch.toggle()
    }

    @objc private func resetTimer() {
        stopwatch.reset()
    }
}
