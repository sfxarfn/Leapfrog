<img width="64" height="64" alt="Leapfrog" src="https://github.com/user-attachments/assets/a80e9d51-e0d3-4711-907e-80e43e9f9c34" />

# Leapfrog

Smooth cursor movement between Mac displays of different sizes and resolutions.

If you've ever had a 4K monitor next to a 1080p one — or a laptop screen next to an external — you've probably noticed that moving the cursor between them feels wrong. The cursor jumps vertically at the edge, gets "stuck" in dead zones, or appears at a completely different height than where you left it. Leapfrog fixes this by tracking where your monitors physically sit on your desk and repositioning the cursor accordingly.

Inspired by the excellent [LittleBigMouse](https://github.com/mgth/LittleBigMouse) for Windows.

---

## What it does

![Concept diagram placeholder — cursor crossing between two monitors of different sizes, aligned physically instead of by pixel count]

When you move your cursor from one monitor to another, Leapfrog:

- Figures out where the cursor *should* land based on the physical positions of your displays (not pixel positions).
- Smoothly repositions the cursor at the physically correct spot on the destination monitor.
- Adds an optional "resistance" delay so you don't accidentally cross into another monitor when clicking near an edge.

It runs quietly in your menu bar and does its work invisibly.

---

## Requirements

- macOS 13 Ventura or newer
- Two or more displays (single-display users don't need this app)
- Accessibility permission (you'll grant this on first launch)

---

## Installation

1. Download the latest `Leapfrog.app`.
2. Drag it into your `/Applications` folder.
3. Double-click to launch. You'll see a small **Leapfrog** icon appear in your menu bar (top-right of your screen, near the clock).

**Note:** Because the app is distributed outside the Mac App Store, macOS may show a warning on first launch. If it does:
- Right-click the app in `/Applications` → **Open** → confirm.
- Or go to **System Settings → Privacy & Security** and click **Open Anyway**.

---

## First-time setup

### Step 1: Grant Accessibility permission

The first time you launch the app, macOS will show a dialog:

> *"Leapfrog would like to control this computer using accessibility features."*

1. Click **Open System Settings**.
2. In **Privacy & Security → Accessibility**, toggle **Leapfrog** on.
3. Enter your password when prompted.
4. **Quit and relaunch the app.** The permission only takes effect after a restart.

Without this permission, the app cannot monitor cursor movement and won't do anything.

### Step 2: Open Preferences

Click the menu bar icon → **Preferences…**. A window opens with two tabs:
- **Layout** — the visual display arranger
- **Info** — a read-only display inventory and the on/off toggle

### Step 3: Arrange your displays

Click the **Layout** tab. You'll see a rectangle for each of your monitors, drawn at their real physical sizes.

**Arrange the rectangles to match your actual desk.** Click and drag each rectangle to reflect where that monitor physically sits. For example:
- If your left monitor sits slightly lower than your right monitor because of different stand heights, drag it down in the app.
- If you have one big monitor centered and a smaller laptop screen to the side, place them accordingly.
- If there's a physical gap between your monitors (say, the bezels + a few cm of desk), leave that gap in the app too.

The rectangles are scaled to real millimeters — what you see reflects actual physical dimensions. A 27" monitor is visibly larger than a 14" laptop screen in the editor.

**Tips:**
- Use the faint 100mm grid in the background as a ruler.
- The footer shows the current zoom level (e.g., "1 mm = 0.85 pt").
- Click **Reload from system** if you plug/unplug a monitor and need to re-detect.
- Click **Reset to defaults** to wipe all your custom positions and start over.

Your changes save automatically as soon as you release a drag. No explicit "Save" button needed.

### Step 4: Test it

Move your cursor between monitors, near the edges where they meet. The cursor should now land at the physically-correct vertical position on the destination monitor, not at some arbitrary pixel offset.

---

## Daily use

The app runs in the background. You don't need to interact with it unless:

- You want to **disable it temporarily** (e.g., for a fullscreen game).
- You **rearrange your monitors** physically.
- You **plug in a new monitor**.

### Turning it off and on

Click the menu bar icon → **Preferences…** → **Info** tab. Use the **Enable cursor remapping** toggle.

When disabled, cursor crossings behave like stock macOS (pixel-aligned, with all the usual quirks). Your saved layout is preserved; flipping the toggle back on restores the behavior instantly.

The toggle persists across app restarts.

### Quitting the app

Menu bar icon → **Quit** (or press ⌘Q while the icon menu is open).

### Relaunch at login

To have the app start automatically when you log in:

1. Open **System Settings → General → Login Items & Extensions**.
2. Under **Open at Login**, click **+**.
3. Navigate to `/Applications`, select `Leapfrog.app`, click **Open**.

Now the app will start silently every time you log in. You won't see a Dock icon or a window — just the menu bar icon.

---

## Features explained

### Physical cursor alignment

The core feature. When your cursor crosses from one monitor to another, the app calculates where the cursor should land based on physical position (in millimeters) rather than pixel position.

**Example:** You have a 27" 4K monitor on the left (2160px tall) and a 24" 1080p monitor on the right (1080px tall), aligned so their centers are at the same height on your desk. Without the app, moving the cursor right from the top of the 4K monitor lands it at pixel row 0 of the 1080p monitor — roughly 7cm above where you were aiming. With the app, it lands at the matching physical height, which is about one-third of the way down the 1080p screen.

### Border resistance

A short delay (default 150ms) when the cursor tries to cross a monitor edge in certain directions. This prevents accidental crossings when you're clicking something near an edge.

**Current behavior:** Resistance is applied only when crossing **leftward** (from a right-positioned monitor into a left-positioned one). Rightward, upward, and downward crossings happen instantly.

If you push the cursor firmly against the edge for longer than the delay, you'll cross through normally. If you're just clicking near the edge and moving back, you won't accidentally slide onto the other monitor.

This is useful if, for example, your dock or a browser tab bar sits near the inner edge of one monitor and you keep overshooting.

### Display information

The **Info** tab in Preferences shows you what the app sees for each monitor:
- System-assigned display ID
- Stable key (used internally for saving layouts that survive reboots)
- Pixel dimensions and screen-space position
- Physical dimensions in millimeters (from EDID)
- World-mm coordinates (your custom arrangement)

Useful for debugging if something looks wrong.

---

## Troubleshooting

### "No displays detected"

Quit and fully relaunch the app. If the issue persists, check the menu bar icon is still there — if not, the app crashed; relaunch from `/Applications`.

### Cursor repositioning isn't happening

1. Confirm Accessibility permission is still granted: **System Settings → Privacy & Security → Accessibility**. The toggle next to **Leapfrog** should be on.
2. Confirm the engine is enabled: Preferences → Info → **Enable cursor remapping** should be on.
3. Confirm the app has detected your displays: Preferences → Info should list each monitor.
4. If you just updated or rebuilt the app, permission may have been reset — toggle it off and on in System Settings, then relaunch the app.

### Cursor lands in the wrong spot

1. Open Preferences → Layout and double-check your rectangles match your physical setup.
2. Check the physical dimensions in the **Info** tab. Some monitors report wrong dimensions via EDID. If yours looks obviously wrong (e.g., a 27" monitor reported as 10mm × 10mm), the fallback is kicking in — you'll need to wait for the physical-size override feature, or adjust by dragging in the Layout tab to compensate.
3. Click **Reload from system** in the Layout tab.

### Cursor feels stuck at the monitor edge

If it's only sticky going **one direction**, that's the border-resistance feature working as designed. Push against the edge and it'll let you through after about 150ms.

If it's stuck in **both directions** or you can't cross at all, something's wrong — disable and re-enable the engine from the Info tab to reset.

### Permission keeps getting asked on every launch

This typically happens if you're rebuilding the app from source (Xcode re-signs on every build). For the installed production app, grant once and it stays.

If the list of entries in **System Settings → Privacy & Security → Accessibility** has accumulated duplicates:
1. Remove all `Leapfrog` entries by selecting each and clicking **−**.
2. Quit the app.
3. Relaunch from `/Applications` and grant permission once. It should now stick.

### Games and fullscreen apps behave oddly

Fullscreen games that capture the cursor (most FPS games, some simulation games) can conflict with the engine. Open Preferences → Info and toggle **Enable cursor remapping** off before gaming, then back on after.

A future version will detect this automatically.

### Plugged in a new monitor, nothing happens

The app should auto-detect new monitors. If not, open Preferences → Layout and click **Reload from system**. The new display should appear.

---

## FAQ

**Does this work with Sidecar / iPad as a second display?**
Partially. Sidecar displays often don't report EDID physical sizes, so the app falls back to a default DPI. Crossing still works, but alignment may not be perfect. The planned physical-size override feature will fix this.

**Does this work with AirPlay / wireless displays?**
Same as Sidecar — works but alignment may need manual tweaking.

**Does this affect performance?**
Negligibly. The app processes mouse-move events, which are already being generated by the system. Overhead is in the microseconds per event.

**Does this work with trackpad gestures?**
Yes. Trackpad movement is just another source of mouse events from the system's perspective.

**Does this affect mouse clicks?**
No. Only movement events (mouse moved + dragged) are intercepted.

**Can I use this with Windows-style "infinite mouse" (wrap to opposite side)?**
Not yet — this is on the roadmap.

**Can I have the app start when I log in?**
Yes — see "Relaunch at login" above.

**Is my data sent anywhere?**
No. The app makes no network connections. Your display layout is stored locally in `~/Library/Preferences`.

**Does this work with three or more monitors?**
Yes. Arrange all of them in the Layout editor. Crossings between any pair are handled.

**Can I back up my layout?**
Your layout is stored in `UserDefaults` under the app's bundle identifier. You can export it with:
```
defaults export com.yourname.Leapfrog ~/Desktop/lbm-backup.plist
```
Restore with:
```
defaults import com.yourname.Leapfrog ~/Desktop/lbm-backup.plist
```
(Replace `com.yourname.Leapfrog` with your actual bundle identifier.)

---

## Privacy

Leapfrog requires Accessibility permission to monitor cursor movement. This is the *only* capability it uses; it does not read keystrokes, record screens, access files, or make network connections.

The app is open-source — you can inspect the code yourself or build from source to verify.

---

## Known limitations

- **Physical sizes from EDID may be wrong** for some monitors. A manual override UI is planned.
- **Games that capture the cursor** need the engine toggled off manually.
- **Border resistance** currently only applies to leftward crossings. Per-direction configuration is planned.
- **No snap-to-edge** when dragging displays in the layout editor yet.
- **Cursor speed across different DPI monitors** is not yet equalized (planned as part of a future "Level 2" engine).

See the Technical Specification for the full roadmap.

---

## Getting help

- **Something broke:** Check the Troubleshooting section above. Still stuck? Open an issue with a description of your display setup and what you expected vs. what happened.
- **Feature request:** Open a GitHub issue labeled "enhancement."
- **Code questions:** See the Technical Specification document.

---

## Credits

- Inspired by [LittleBigMouse](https://github.com/mgth/LittleBigMouse) by Mathieu GRENET (Windows original).
- Built with SwiftUI and CoreGraphics on macOS.

---

## License

*[Add your license here — MIT and BSD-2-Clause are common choices for small utilities.]*
