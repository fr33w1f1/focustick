import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var statusItem: NSStatusItem!
    private var stopwatch: StopwatchManager!
    private var hotkey: GlobalHotkeyManager!
    private var idleManager: IdleManager!

    private var startStopMenuItem: NSMenuItem!
    private var resetMenuItem: NSMenuItem!
    private var idleMenu: NSMenu!

    private let idleThresholdKey = "idleThreshold"

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as a background agent — no Dock icon, no app switcher entry
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        setupMenu()

        stopwatch = StopwatchManager { [weak self] timeString, isRunning in
            self?.updateDisplay(timeString: timeString, isRunning: isRunning)
        }

        let savedThreshold = UserDefaults.standard.double(forKey: idleThresholdKey)
        // Default to 5 mins if not set or 0 (if 0 was intended as disabled, we handle that in setupMenu)
        let threshold = savedThreshold == 0 ? 300.0 : savedThreshold
        
        idleManager = IdleManager(threshold: threshold) { [weak self] in
            self?.stopwatch.stop()
        }

        hotkey = GlobalHotkeyManager { [weak self] in
            self?.stopwatch.toggle()
        }
        hotkey.register()
        
        updateIdleMenuSelection()
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

        // Idle Timeout Submenu
        let idleMenuItem = NSMenuItem(title: "Idle Timeout", action: nil, keyEquivalent: "")
        idleMenu = NSMenu()
        
        let options: [(String, TimeInterval)] = [
            ("Off", 0),
            ("1 minute", 60),
            ("2 minutes", 120),
            ("5 minutes", 300),
            ("10 minutes", 600),
            ("15 minutes", 900),
            ("30 minutes", 1800)
        ]

        for (title, value) in options {
            let item = NSMenuItem(title: title, action: #selector(setIdleTimeout(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = value
            idleMenu.addItem(item)
        }
        
        idleMenuItem.submenu = idleMenu
        menu.addItem(idleMenuItem)

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
            
            if isRunning {
                self.idleManager.startMonitoring()
            } else {
                self.idleManager.stopMonitoring()
            }
        }
    }

    // MARK: - Actions

    @objc private func toggleTimer() {
        stopwatch.toggle()
    }

    @objc private func resetTimer() {
        stopwatch.reset()
    }

    @objc private func setIdleTimeout(_ sender: NSMenuItem) {
        guard let threshold = sender.representedObject as? TimeInterval else { return }
        idleManager.threshold = threshold
        UserDefaults.standard.set(threshold, forKey: idleThresholdKey)
        updateIdleMenuSelection()
    }

    private func updateIdleMenuSelection() {
        let currentThreshold = idleManager.threshold
        for item in idleMenu.items {
            if let value = item.representedObject as? TimeInterval {
                item.state = (value == currentThreshold) ? .on : .off
            }
        }
    }
}
