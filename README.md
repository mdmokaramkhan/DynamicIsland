# 🏝️ DynamicIsland

Minimal macOS Dynamic Island-style overlay built with SwiftUI + AppKit.

---

## ✨ Features

- 🖤 Floating black island at top center
- 🧩 Custom notch shape (flat top + curved wings + rounded bottom)
- 🖱️ Smooth hover expand / collapse animation
- 🪟 Borderless, transparent `NSPanel`
- 🙈 Runs without Dock icon (accessory app)

---

## 🛠️ Stack

- 🍎 Swift
- 🎨 SwiftUI
- 🧱 AppKit

---

## ▶️ Run

1. Open `DynamicIsland.xcodeproj`
2. Select your Mac target
3. Press `Cmd + R`

---

## 📁 Key Files

- `DynamicIsland/NotchShape.swift` → island shape
- `DynamicIsland/DynamicIslandView.swift` → hover animation UI
- `DynamicIsland/IslandPanel.swift` → floating panel setup
- `DynamicIsland/AppDelegate.swift` → lifecycle + positioning

---

## 🎛️ Quick Customize

Edit in `DynamicIsland/DynamicIslandView.swift`:

- `collapsedSize` / `expandedSize`
- `collapsedTopRadius` / `expandedTopRadius`
- `collapsedBottomRadius` / `expandedBottomRadius`
