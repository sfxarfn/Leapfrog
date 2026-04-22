# Micer — Technical Specification

**Version:** 0.1 (MVP)
**Platform:** macOS 13 Ventura or newer
**Language:** Swift 5.9+
**UI Framework:** SwiftUI + AppKit interop
**Build System:** Xcode 15+

---

## 1. Overview

### 1.1 Purpose

Micer is a macOS menu-bar utility that corrects cursor behavior when moving between monitors of different physical sizes and/or resolutions. It is inspired by and functionally analogous to the Windows application **LittleBigMouse** by Mathieu GRENET.

### 1.2 Problem Statement

macOS arranges multiple displays in a unified pixel coordinate space (`CGDisplayBounds`). When two adjacent monitors have different pixel dimensions, DPIs, or physical sizes, moving the cursor across their shared edge produces jarring behavior:

- The cursor appears at a different vertical position than where it exited.
- Monitors with different DPIs cause perceived cursor speed to differ per screen.
- Edge zones with no corresponding pixels on the neighboring display create "dead zones" where the cursor cannot cross.

### 1.3 Solution Approach

The app intercepts mouse movement events via a `CGEventTap`, detects when the cursor is crossing from one display to another, and replaces the default pixel-based crossing behavior with a physically-aligned crossing based on each display's real-world millimeter layout. A user-editable world-mm map stored in `UserDefaults` defines this layout.

### 1.4 Scope of This Document

This document describes the current MVP implementation. Level-2 features (full cursor decoupling via `CGAssociateMouseAndMouseCursorPosition(0)`, uniform-speed cursor movement across DPIs, snap-to-edge dragging, game detection) are discussed as future work in §10.

---

## 2. High-Level Architecture

```
┌──────────────────────────────────────────────────────────┐
│                  MicerApp                    │
│                     (SwiftUI App)                        │
│                                                          │
│  ┌────────────────┐        ┌───────────────────────┐     │
│  │  MenuBarExtra  │        │   @StateObject        │     │
│  │   MenuContent  │◀──────▶│   DisplayManager      │     │
│  └────────┬───────┘        └──────────┬────────────┘     │
│           │                           │                  │
│           │ opens                     │ observes         │
│           ▼                           ▼                  │
│  ┌──────────────────────┐   ┌─────────────────────┐      │
│  │ PreferencesWindow    │   │    LayoutStore      │      │
│  │    Controller        │   │   (UserDefaults)    │      │
│  │                      │   └─────────────────────┘      │
│  │  SettingsView        │                                │
│  │   ├─ LayoutEditor    │                                │
│  │   └─ DisplayInfo     │                                │
│  └──────────────────────┘                                │
│                                                          │
│  ┌──────────────────────────────────────────────────┐    │
│  │                   AppDelegate                    │    │
│  │  (owns MouseEngine lifecycle, static .shared)    │    │
│  └────────────────────┬─────────────────────────────┘    │
│                       │                                  │
│                       ▼                                  │
│  ┌──────────────────────────────────────────────────┐    │
│  │                  MouseEngine                     │    │
│  │   CGEventTap → handle() → synthetic CGEvent      │    │
│  └──────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────┘
```

### 2.1 Module Responsibilities

| Module | Responsibility |
|---|---|
| `MicerApp` | SwiftUI app entry point, owns `DisplayManager` as `@StateObject`, wires `MenuBarExtra` |
| `AppDelegate` | App lifecycle, engine start/stop, screen-change observer, static shared instance |
| `DisplayManager` | Enumerates displays, merges EDID with user overrides, publishes `@Published` list |
| `LayoutStore` | JSON-encoded UserDefaults persistence for per-display layout |
| `MouseEngine` | Installs `CGEventTap`, detects crossings, posts synthetic events |
| `PermissionHelper` | Requests and checks Accessibility permission |
| `EnginePreferences` | Enable/disable flag persisted to UserDefaults |
| `PreferencesWindowController` | Hand-rolled `NSWindow` hosting `SettingsView` |
| `SettingsView` | Tabbed Preferences UI container |
| `LayoutEditorView` | Drag-to-arrange mm-space display editor |
| `DisplayInfoView` | Read-only display inventory plus engine toggle |
| `MenuContent` | Menu items shown in `MenuBarExtra` dropdown |

---

## 3. Domain Model

### 3.1 Coordinate Systems

Three distinct coordinate spaces are used. All conversions must be explicit.

| Space | Origin | Unit | Produced by | Consumed by |
|---|---|---|---|---|
| **Pixel (global)** | Top-left of primary display | Pixels | `CGDisplayBounds`, `CGEvent.location`, `CGWarpMouseCursorPosition` | Event tap, synthetic event posting |
| **World (mm)** | Arbitrary user-defined | Millimeters | `LayoutStore`, `LayoutEditorView` | `MouseEngine.physicallyAlign` |
| **AppKit** | Bottom-left of primary display | Points | `NSScreen.frame`, `NSEvent.mouseLocation` | Unused in core logic; SwiftUI only |

CoreGraphics (top-left) is the canonical coordinate system for this app. AppKit bottom-left coordinates must be flipped at boundaries if ever used.

### 3.2 `Display` Struct

```swift
struct Display: Identifiable, Hashable {
    let id: CGDirectDisplayID        // system-assigned, not stable across reboots
    var pixelFrame: CGRect           // global pixel space, top-left origin
    var physicalSize: CGSize         // millimeters
    var worldOriginMM: CGPoint       // this display's top-left in world-mm space
    var stableKey: String            // persistent cross-reboot identifier
    var isPrimary: Bool              // CGDisplayIsMain == 1
}
```

**Computed properties:**
- `pixelsPerMM: CGSize` — derived from `pixelFrame.size / physicalSize`. Falls back to `(4, 4)` (~100 DPI) when `physicalSize` is zero.
- `pixelToWorldMM(_:) → CGPoint` — converts a local pixel coordinate to world-mm.
- `worldMMToPixel(_:) → CGPoint` — inverse of the above.

### 3.3 Stable Display Keys

`CGDirectDisplayID` values are not stable across reboots or display reconnects, so saved layouts cannot key off them directly. `DisplayManager.stableKey(for:)` produces a durable identifier:

- Built-in display → `"builtin"` (used on all Apple Silicon laptops and iMacs).
- External displays → `"{vendor}-{model}-{serial}"` from `CGDisplayVendorNumber`, `CGDisplayModelNumber`, `CGDisplaySerialNumber`.
- Fallback when EDID is absent → `"id-{rawID}"` (non-stable; behaves as single-session only).

### 3.4 Persistence Schema

Stored at `UserDefaults.standard` under key `"displayLayouts.v1"` as JSON:

```json
{
  "builtin": {
    "worldOriginMM": { "x": 0, "y": 0 },
    "physicalSizeMMOverride": null
  },
  "1552-40962-123456": {
    "worldOriginMM": { "x": 302, "y": -12 },
    "physicalSizeMMOverride": { "width": 598, "height": 336 }
  }
}
```

The `.v1` suffix reserves namespace for future schema migrations. `physicalSizeMMOverride` is currently only readable; writing it is planned for a future UI feature.

The engine enable/disable flag is stored separately under `"engineEnabled"` (Bool).

---

## 4. Mouse Engine

### 4.1 Event Tap Configuration

```swift
CGEvent.tapCreate(
    tap: .cgSessionEventTap,         // user session scope
    place: .headInsertEventTap,      // first-in-chain; runs before other apps
    options: .defaultTap,            // can modify or drop events
    eventsOfInterest: mask,          // mouseMoved + all three dragged variants
    callback: eventTapCallback,
    userInfo: Unmanaged.passUnretained(self).toOpaque()
)
```

Event mask covers `.mouseMoved`, `.leftMouseDragged`, `.rightMouseDragged`, `.otherMouseDragged`. Drag events are included so crossing behavior works while a mouse button is held (e.g., dragging a window between displays).

The run-loop source is attached to `CFRunLoopGetMain()` on `.commonModes` so the tap remains active even while modal UI is shown.

### 4.2 Callback Flow

```
Hardware event ─▶ CGEventTap ─▶ eventTapCallback (C function)
                                       │
                                       ▼
                                MouseEngine.handle(event:type:)
                                       │
                        ┌──────────────┼──────────────────────────┐
                        ▼              ▼                          ▼
               tap-disabled      synthetic (marker)?         real mouse event
                  re-enable          pass through            │
                  return              return                 ▼
                                                      same display as last?
                                                  ┌─────┴──────┐
                                                  Yes          No
                                                  ▼            ▼
                                           update state,   crossing block
                                           return event    (see §4.3)
```

The C callback is necessary because `CGEventTap` expects a C function pointer. It unpacks `userInfo` back to `MouseEngine` via `Unmanaged`. All business logic lives in `handle(event:type:)`.

### 4.3 Crossing Block

When `handle` detects the cursor has moved into a different display than `lastDisplayId`, it enters the crossing block:

1. Determine `CrossingDirection` by comparing source and destination display centers (`left`, `right`, `up`, `down`).
2. Compute `corrected` — the physically-aligned landing point on the destination display — via `physicallyAlign(from:exit:to:attempted:)`.
3. Apply direction-conditional delay (see §4.4).
4. When the crossing fires:
   a. Create a synthetic `.mouseMoved` `CGEvent` at `corrected`.
   b. Stamp it with `Self.syntheticEventMarker` via `setIntegerValueField` on field `100`.
   c. Post it with `.cghidEventTap`.
   d. Return `nil` to drop the original hardware event.
5. Update `lastPosition` and `lastDisplayId`.

### 4.4 Border Resistance (Delay)

Controlled by `borderDelayMS` (default `150`) and `pendingCrossing: (fromId, toId, startedAt)?`.

**Algorithm per hardware event inside the crossing block:**

```
if direction does not require delay:
    cross immediately
else:
    if pendingCrossing matches (fromId, toId):
        use its startedAt
    else:
        pendingCrossing = (fromId, toId, now)

    elapsedMS = now - pendingCrossing.startedAt
    if elapsedMS >= borderDelayMS:
        cross; clear pendingCrossing
    else:
        drop event (return nil); cursor stays clamped at source edge by OS
```

If the cursor leaves the edge (no longer crossing) before the delay elapses, `pendingCrossing` is cleared, and a fresh timer starts on the next crossing attempt.

Direction policy (current): delay applied only when `direction == .left`. This is user-configurable in code via the `requiresDelay` expression in `handle(event:type:)`. A future UI will expose per-direction toggles.

### 4.5 Physical Alignment

```swift
func physicallyAlign(from: Display, exit: CGPoint,
                     to: Display, attempted: CGPoint) -> CGPoint {
    let worldMM = from.pixelToWorldMM(exit)
    var target = to.worldMMToPixel(worldMM)
    target.x = max(to.pixelFrame.minX + 1, min(to.pixelFrame.maxX - 1, target.x))
    target.y = max(to.pixelFrame.minY + 1, min(to.pixelFrame.maxY - 1, target.y))
    return target
}
```

The exit point on the source display is converted to world-mm coordinates, then back-converted to pixel coordinates on the destination display. The result is clamped to a 1-pixel inset from the destination's bounds to avoid re-triggering a crossing on the next event.

### 4.6 Synthetic Event Marker

To prevent the tap from reprocessing events it posted itself (which would cause infinite recursion or double-crossing), synthetic events are stamped:

```swift
private static let syntheticEventField = CGEventField(rawValue: 100)!
private static let syntheticEventMarker: Int64 = 0xB16B00B5
```

Field `100` is outside the range of system-reserved `CGEventField` values, making it safe to reuse for a custom flag. The marker value is arbitrary; any sentinel pattern works.

On entry to `handle`, events carrying this marker are passed through immediately with no state changes.

### 4.7 Tap Disable Recovery

macOS may disable the tap if a callback runs too slowly (`.tapDisabledByTimeout`) or if a user input event is held (`.tapDisabledByUserInput`). Both cases are handled by re-enabling the tap:

```swift
if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
    if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
    return event
}
```

### 4.8 Lifecycle: start() and stop()

`start()` creates the tap, builds and installs a run-loop source, enables the tap, and seeds `lastPosition` / `lastDisplayId` from the current cursor position.

`stop()` disables the tap, invalidates the Mach port via `CFMachPortInvalidate`, removes the run-loop source, and clears internal state (`pendingCrossing`). Calling `start()` after `stop()` produces a clean new tap — there is no residual state.

---

## 5. SwiftUI Integration

### 5.1 Application Structure

```swift
@main
struct MicerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var displayManager: DisplayManager

    init() {
        let manager = DisplayManager()
        _displayManager = StateObject(wrappedValue: manager)
        AppDelegate.sharedManagerBootstrap = manager
    }

    var body: some Scene {
        MenuBarExtra("Micer", systemImage: "rectangle.on.rectangle") {
            MenuContent()
                .environmentObject(displayManager)
        }
        .menuBarExtraStyle(.menu)
    }
}
```

**Key design choices:**
- `DisplayManager` is a `@StateObject` owned by the App struct, not the delegate. This guarantees it exists before any view renders.
- `AppDelegate.sharedManagerBootstrap` is a static handoff mechanism: the App struct's `init` stashes the manager there; `applicationDidFinishLaunching` picks it up. This avoids race conditions inherent to `@NSApplicationDelegateAdaptor` property access.
- No `Settings { ... }` scene is declared. Preferences use a hand-rolled `NSWindow` (see §5.3). This is because `MenuBarExtra` + `SettingsLink` + `.accessory` activation policy has reliability issues across macOS versions.

### 5.2 AppDelegate as Shared Singleton

```swift
final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var shared: AppDelegate?
    static var sharedManagerBootstrap: DisplayManager?

    override init() {
        super.init()
        AppDelegate.shared = self
    }
    // ...
}
```

`NSApp.delegate` cannot be reliably cast back to `AppDelegate` when using `@NSApplicationDelegateAdaptor` — SwiftUI may install a wrapper delegate. `AppDelegate.shared` bypasses this entirely, set at `init` time (the earliest possible moment).

### 5.3 Preferences Window

A hand-managed `NSWindow` hosting a SwiftUI root via `NSHostingController`:

```swift
final class PreferencesWindowController {
    static let shared = PreferencesWindowController()
    private var window: NSWindow?

    func show(manager: DisplayManager) {
        if let existing = window {
            NSApp.activate(ignoringOtherApps: true)
            existing.makeKeyAndOrderFront(nil)
            return
        }
        let root = SettingsView().environmentObject(manager)
        let hosting = NSHostingController(rootView: root)
        let w = NSWindow(contentViewController: hosting)
        w.title = "Micer Preferences"
        w.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        w.setContentSize(NSSize(width: 700, height: 480))
        w.center()
        w.isReleasedWhenClosed = false
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: w, queue: .main
        ) { [weak self] _ in self?.window = nil }
        window = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }
}
```

`isReleasedWhenClosed = false` together with the `willClose` notification lets us reuse the window on subsequent "Preferences…" clicks within a single session without leaking.

### 5.4 DisplayManager as ObservableObject

```swift
final class DisplayManager: ObservableObject {
    @Published private(set) var displays: [Display] = []
    // ...
}
```

All SwiftUI views consuming the manager use `@EnvironmentObject`. Mutations in `setWorldOrigin(_:for:)` directly modify the `displays` array, which triggers `@Published` notifications and view refreshes. No manual `objectWillChange.send()` calls are needed.

All writes to `displays` must happen on the main thread; `refresh()` enforces this by dispatching to main when called from a background thread.

### 5.5 Layout Editor Interaction

The editor renders displays as `ZStack`-composed rectangles. Each rectangle reads its origin from `dragOrigins[display.id] ?? display.worldOriginMM`:

- During a drag, `dragOrigins[display.id]` is updated on every `.onChanged`, overriding the stored position visually.
- On `.onEnded`, `manager.setWorldOrigin(_:for:)` persists the final position, and the entry is removed from `dragOrigins`. The rectangle re-reads from the observed manager state on the next render tick.

The transform (world-mm → view points) is computed per-render in `computeTransform(in:)` by bounding-boxing all display rectangles and fitting them to the available `GeometryReader` space with 30pt padding. Scale is reported in the footer for user reference.

---

## 6. Permissions

### 6.1 Accessibility

Required for `CGEventTap` to receive events from other applications. Requested via:

```swift
AXIsProcessTrustedWithOptions(
    [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
)
```

This call:
- Returns `true` if already granted.
- Returns `false` if not granted, and shows a system prompt directing the user to System Settings.

The prompt cannot be auto-dismissed; user must manually toggle the app in **System Settings → Privacy & Security → Accessibility** and relaunch.

### 6.2 Permission Persistence Across Builds

Accessibility permission is granted per code-signature. Debug builds from Xcode are re-signed on every build, causing the permission to reset. Mitigations:

- Stable signing via **Apple Development** identity in both Debug and Release configurations (set in Build Settings).
- Cleanup of stale entries in System Settings when they accumulate.
- For production use, install the Release-configuration build into `/Applications`; once granted, permission sticks.

A programmatic reset is available via Terminal:
```
tccutil reset Accessibility com.yourname.Micer
```

### 6.3 Sandbox

The app must **not** be sandboxed. `CGEventTap` requires entitlements that are incompatible with `com.apple.security.app-sandbox`. The App Sandbox capability is explicitly removed from the target.

This precludes App Store distribution. Distribution is via Developer ID signing + notarization + direct download, or (for personal/internal use) ad-hoc signed local builds.

---

## 7. File Layout

```
Micer/
├── MicerApp.swift        # App entry point, @StateObject wiring
├── AppDelegate.swift                 # Lifecycle, shared singleton, engine control
├── PermissionHelper.swift            # Accessibility check/request
├── EnginePreferences.swift           # Engine enable flag (UserDefaults)
├── DisplayManager.swift              # Display enumeration + model types
├── LayoutStore.swift                 # UserDefaults persistence layer
├── MouseEngine.swift                 # CGEventTap, crossing logic, border delay
├── PreferencesWindowController.swift # NSWindow wrapper for Preferences
├── MenuContent.swift                 # Menu bar dropdown contents
├── SettingsView.swift                # Tabbed container + DisplayInfoView
├── LayoutEditorView.swift            # Drag-to-arrange mm-space editor
├── Assets.xcassets/                  # Icons, accent color
└── Info.plist                        # LSUIElement=YES
```

---

## 8. Runtime Behavior

### 8.1 Launch Sequence

1. `MicerApp.init()` runs — creates `DisplayManager`, stashes in `AppDelegate.sharedManagerBootstrap`.
2. `@NSApplicationDelegateAdaptor` instantiates `AppDelegate`; its `init` sets `AppDelegate.shared = self`.
3. SwiftUI registers the App with AppKit.
4. `applicationDidFinishLaunching` fires:
   - Activation policy set to `.accessory` (no Dock icon).
   - Accessibility permission requested.
   - `displayManager` assigned from bootstrap.
   - Screen-change observer registered.
   - `startEngineIfEnabled()` called — if the preference is on and permission granted, the `MouseEngine` starts.
5. `MenuBarExtra` appears in the menu bar.

At this point the engine is running if conditions are met. No user action is required.

### 8.2 Display Change Handling

`NSApplication.didChangeScreenParametersNotification` fires on display connect, disconnect, resolution change, or arrangement change. Handler calls `displayManager.refresh()`, which:

1. Re-enumerates active displays via `CGGetActiveDisplayList`.
2. For each, re-applies any saved layout matching the stable key.
3. Publishes the new list.
4. All SwiftUI views observing the manager update automatically.
5. The `MouseEngine` continues running; its next event reads the updated display list.

### 8.3 Engine Toggle

`DisplayInfoView` binds a `Toggle` to a manual `Binding` whose setter:

1. Writes the new value to `EnginePreferences.isEnabled`.
2. Calls `AppDelegate.shared.startEngineIfEnabled()` or `stopEngine()`.

`startEngineIfEnabled()` is idempotent; calling it when already running is a no-op. `stopEngine()` tears the tap down fully.

### 8.4 Cursor Crossing Behavior

Given two displays A (left) and B (right), physically aligned so that B's top is 20mm below A's top:

- **User moves cursor from A → B (rightward):** No delay. The exit point on A is mapped to world-mm, re-mapped to B's pixel space, and the cursor appears at the equivalent physical vertical position on B. A synthetic `.mouseMoved` event is posted at this position; the original event is dropped.
- **User moves cursor from B → A (leftward):** 150ms delay enforced. Hardware events during the delay are dropped; the cursor remains clamped at B's left edge. After 150ms, the next crossing event triggers the corrected crossing.
- **User moves away from the edge before 150ms:** `pendingCrossing` is cleared; next crossing attempt starts a fresh timer.

---

## 9. Known Limitations

- **EDID physical sizes may be wrong or missing.** Some displays report zero or incorrect dimensions. Fallback is 100 DPI. A user override UI (`physicalSizeMMOverride` in the schema) is planned but not yet built.
- **No snap-to-edge in the layout editor.** Placing displays perfectly adjacent requires manual precision.
- **Horizontal layouts only.** `physicallyAlign` works for any layout, but the delay's direction policy and the editor are designed primarily for side-by-side configurations.
- **Game compatibility.** Fullscreen games that capture the mouse (`CGAssociateMouseAndMouseCursorPosition(0)`) will conflict with the engine. No automatic detection yet; user can toggle the engine off manually.
- **Event-tap disable on high CPU load.** If the tap callback is starved, macOS disables it. Recovery logic re-enables, but events during the dead window are lost.
- **Mach port cleanup.** `stop()` invalidates the port; a subsequent `start()` creates a fresh one. A rare case: if `stop()` is called from a non-main thread, behavior is undefined. Current code calls it only from the main thread.
- **No multi-user handling.** UserDefaults is per-user, which is correct; but if two users have the same external monitor, their layouts are independent. This is intentional.

---

## 10. Future Work

In rough order of payoff:

1. **Physical-size override UI.** Inspector in the layout editor for typing monitor dimensions.
2. **Snap-to-edge dragging.** Detect when a dragged display is close to another's edge and snap it.
3. **Per-direction delay configuration.** Expose all four directions and their delays in Preferences.
4. **Level-2 engine.** Decouple the cursor via `CGAssociateMouseAndMouseCursorPosition(0)`, integrate mouse deltas in mm-space directly. Equalizes cursor speed across DPI-different monitors.
5. **Game-mode auto-pause.** Detect fullscreen focused apps via `CGDisplayIsCaptured` or frontmost-app inspection; disable the engine while a known game is frontmost.
6. **Launch at login.** Wire `SMAppService.mainApp.register()` for one-click setup.
7. **Color/brightness profile sync.** LittleBigMouse's per-monitor color-balance feature; useful when physical color calibration differs.
8. **Multi-arrangement profiles.** Save and switch between layouts (e.g., "desk" vs "travel").
9. **Menu bar quick-toggle.** Engine on/off item in the `MenuBarExtra` dropdown without opening Preferences.
10. **Preferences for border resistance.** Slider for `borderDelayMS`, toggle for per-direction policy.

---

## 11. Build and Distribution

### 11.1 Development

- Open `Micer.xcodeproj` in Xcode 15+.
- Set the scheme target to **My Mac**.
- Press ⌘R to build and run.

### 11.2 Release

- **Product → Scheme → Edit Scheme → Run → Build Configuration: Release.**
- **Product → Build** (⌘B).
- **Product → Show Build Folder in Finder** → `Build/Products/Release/Micer.app`.
- Copy to `/Applications` manually.

### 11.3 Production (future)

- Apple Developer ID signing: `codesign --deep --sign "Developer ID Application: …" Micer.app`.
- Notarization via `notarytool submit` / `xcrun notarytool`.
- Stapling via `xcrun stapler staple`.
- Distribution via direct download (DMG or ZIP). Not eligible for App Store due to sandbox incompatibility.

---

## 12. References

- **LittleBigMouse (Windows):** https://github.com/mgth/LittleBigMouse
- **Apple Developer Documentation:**
  - `CGEventTap`: https://developer.apple.com/documentation/coregraphics/quartz_event_services
  - `CGDirectDisplay`: https://developer.apple.com/documentation/coregraphics/quartz_display_services
  - `NSApplication.didChangeScreenParametersNotification`
  - `AXIsProcessTrustedWithOptions`
- **Inspiration (macOS cursor utilities):** Linearmouse, Karabiner-Elements, Rectangle.

---

*End of specification.*
