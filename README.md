# 🏝️ DynamicIsland

**DynamicIsland** brings a **Dynamic Island–style** pill to your Mac: it **grows when you hover**, shows **now playing media**, your **latest keystroke**, and the **frontmost app icon**, and can play **optional** key and mouse sounds.

There’s **no Dock icon** — you control everything from the **menu bar**, with a small overlay at the top of the screen.

**Author:** [mdmokaramkhan](https://github.com/mdmokaramkhan) — star the repo if you find it useful.

---

## ✨ What you get

- **Living island** — small idle pill, smooth hover expansion, quick typing strip when you press keys  
- **Context** — see which app is focused and the last key you hit  
- **Now Playing** — Apple Music / Spotify track info and playback controls
- **Sounds** — optional feedback for keys and clicks (off anytime)  
- **Menu controls** — turn capture and sounds on or off without quitting  

---

## 🚀 How to use

1. Launch **DynamicIsland**  
2. Click the **island icon** in the **menu bar**  
3. **Hover** the pill at the top of the screen to expand it  
4. Play something in **Apple Music** or **Spotify**, then use the **Now Playing** tab  
5. **Type** — the island opens briefly with the app icon and latest key  
6. Use the menu for status, options, and **Quit**  

**Tip:** The pill is meant to sit near the top of the display, like a real island.

---

## 🎛️ Menu bar

| Section | What you’ll find |
|---------|------------------|
| **Status** | Whether capture is ready, active, needs Accessibility, or paused |
| **Monitoring** | Enable / disable keystroke capture · open **Accessibility** settings |
| **Media** | Open **Automation** settings for Apple Music / Spotify control |
| **Sound** | Enable / disable key and click sounds |
| **App** | Quit DynamicIsland (shortcut **Q** when the menu is open) |

Menu items use small icons so the list is easy to scan.

---

## 🔐 Privacy

DynamicIsland needs **Accessibility** so macOS can allow keyboard observation for the overlay.

**System Settings → Privacy & Security → Accessibility** → turn on **DynamicIsland**.

The **Now Playing** tab also needs **Automation** permission to read and control Apple Music or Spotify. Start one of those apps, open the island, tap **Setup** in the Now Playing tab, then allow DynamicIsland when macOS prompts.

You can review this later in **System Settings → Privacy & Security → Automation**.

If you downloaded a build and macOS blocks it: **Right-click the app → Open → Open** once.

---

## 💡 Tips

- Pause capture from the menu if you want the island without live keystrokes  
- Turn sounds off for meetings or quiet work  
- If media controls do not appear, start a real track in Apple Music or Spotify, tap refresh, and confirm Automation access  

---

## 👥 Who it’s for

Anyone who wants a **lightweight, visual** menu-bar utility — playful typing feedback without a full windowed app.

---

## 🛠️ Build from source

1. Open `DynamicIsland.xcodeproj` in Xcode  
2. Select **My Mac**  
3. Run (**⌘R**)  

**Source & releases:** [github.com/mdmokaramkhan](https://github.com/mdmokaramkhan)

---

## 🔮 Possible next steps

Ideas only, not a roadmap: themes, idle widgets, multi-display polish, signed/notarized releases for easier sharing.

---

## 📜 License

Add a `LICENSE` file if you want clear reuse terms; otherwise default copyright applies.

---

Made by **[Mohammad Mokaram Khan](https://github.com/mdmokaramkhan)**
