# FocusTick
![](images/Screenshot092931.png)


A stopwatch that lives entirely in the macOS menu bar.  
No window. No Dock icon. Control + \ to start and stop.

```
● 04:23   ← running
  04:23   ← stopped
  00:00   ← idle (default)
```

---

## Project Structure

```
keytick/
├── FocusTick.xcodeproj/       ← open this in Xcode
│   └── project.pbxproj
└── FocusTick/
    ├── main.swift             ← NSApplication entry point
    ├── AppDelegate.swift      ← status item + menu wiring
    ├── StopwatchManager.swift ← timer engine (DispatchSourceTimer)
    ├── GlobalHotkeyManager.swift ← ⌃\ global hotkey (CGEventTap)
    └── Info.plist             ← LSUIElement=YES, no storyboard
```

## Quick Start (No Xcode GUI)

If you have Xcode installed but don't want to open the IDE, you can build and run the app directly from your terminal:

```bash
chmod +x run.sh
./run.sh
```

This will compile the project, create a `build/` directory, and launch the app in your menu bar.

---

## Run in Xcode

1. **Open the project**
   ```bash
   open FocusTick.xcodeproj
   ```

2. **Set your Team**  
   In Xcode → click `FocusTick` in the Project Navigator → target `FocusTick` → *Signing & Capabilities* → set your Apple ID / personal team.  
   *(Free account works — no App Store submission needed.)*

3. **Run**  
   Press **⌘R** or Product → Run.  
   The app will appear in your menu bar; no window, no Dock icon.

---

## Features

### Idle Timeout
FocusTick can automatically stop the clock if it detects no keyboard or mouse activity for a set period. You can configure this via the menu:
- **Off**: The clock will only stop when you manually toggle it.
- **1, 2, 5, 10, 15, or 30 minutes**: The clock stops automatically after the selected duration of inactivity.
- Settings are persisted across launches.

### Global Hotkey
The global hotkey uses `CGEventTap`, which requires **Accessibility** permission.
On first launch (or if the hotkey doesn't respond):
> **System Settings → Privacy & Security → Accessibility → add FocusTick**

The app shows an alert with a direct deep-link if permission is missing.  
The menu still works without the permission — only the hotkey requires it.

---

## Usage

| Action | Effect |
|---|---|
| **control + \\** (global) | Toggle start / stop |
| Click menu bar → **Start** | Start |
| Click menu bar → **Stop** | Stop |
| Click menu bar → **Reset** | Reset to `00:00` |
| Click menu bar → **Idle Timeout** | Set inactivity threshold |
| Click menu bar → **Quit** | Quit |

### Display format
- `00:00` — MM:SS (default, under 1 hour)
- `01:00:00` — HH:MM:SS (auto-switches at 60 minutes)

---

## Customising the Hotkey

Default is **⌘\\** (keycode 42, US layout).  
To change it, edit `GlobalHotkeyManager.swift`:

```swift
var targetKeyCode: Int64 = 42   // ← replace with your key code
```

Common key codes:  
`36` = Return, `48` = Tab, `49` = Space, `51` = Delete, `53` = Escape

To find a key code: add a temporary `print(keyCode)` inside the callback's event handler.

---

## Architecture Notes

- **`LSUIElement = YES`** in `Info.plist` → no Dock icon, no App Switcher entry.
- **`StopwatchManager`** runs its timer on a private `DispatchQueue` with `.userInteractive` QoS and tight leeway (10 ms). Callbacks are dispatched to main for UI updates.
- **`GlobalHotkeyManager`** installs a session-level `CGEventTap` at `.headInsertEventTap` so it intercepts before other apps. The matched event is consumed (`return nil`) so **⌘\\** doesn't trigger anything else.
- Memory: the C callback holds an `Unmanaged` (retained) reference to `GlobalHotkeyManager`. It is balanced by the `release()` call in the fallback path when tap creation fails, and by ARC when the manager is deallocated.

---

## Build for Distribution (optional)

```bash
xcodebuild -project FocusTick.xcodeproj \
           -scheme FocusTick \
           -configuration Release \
           -archivePath build/FocusTick.xcarchive \
           archive
```

Then export the `.app` bundle from `build/FocusTick.xcarchive/Products/Applications/`.

---

## Requirements

- macOS 13 Ventura or later  
- Xcode 15+
