# Changelog

## 0.12.0

- Window-title profile rules: app bundle prefix + focused title → profile.
- Rule editor with "Use current app" / "Use current title".
- Rules win over profile autoFor; focused title is checked every 1.5 s.
- Needs Accessibility permission; troubleshooting and config docs updated.

## 0.11.0

- Combos: modifier + key → another key (e.g. ⌃⌥ + H → LeftArrow).
- Combo editor with modifier toggles and From/To key pickers.
- Separate master switches for layers and combos; both start off after relaunch.
- Combo engine shares the existing event tap and Accessibility permission.

## 0.10.0

- Layer editor: change trigger and mappings from the UI.
- Layer renamed from "Caps = Vim navigation" to "Caps = Navigation".
- Layers always start off when the app launches, even if they were enabled before.
- `Edit` button, add/remove/change mapping, reset to defaults.

## 0.9.0

- Layers (beta): hold Caps Lock for Vim-style navigation.
- Event-tap engine with an emergency off switch and default-off config.
- Accessibility permission card with copy-path and System Settings shortcuts.
- `mackey68://layers` and `mackey68://layers-off` shortcuts.
- hidutil trigger remap pauses only while the tap is actually running.

## 0.8.0

- Renamed Keyboard Lab to **Key Test** / **Test phím**.
- Coverage test: progress, untested key list, green checkmarks on the board.
- Tester shows the physical key and the mapped result.
- Copy diagnostic report (version, keyboard, layout, profile, coverage, chatter, events).
- Menu bar item and `mackey68://test` shortcut.

## 0.7.0

- Keyboard Lab: press a real key to select it on the board.
- Live HID tester with key name, usage code and timing.
- Chatter detection (two key-downs within 50 ms).
- Input Monitoring permission card with a direct shortcut to System Settings.
- `mackey68://lab` and `--lab` open the lab directly.

## 0.6.0

- Rename, duplicate, delete and set a default profile.
- `defaultProfileID` in config, backward compatible with old configs.
- Two more presets: Caps/Ctrl swap and Right Alt as Command.
- Profile menu (⋯) next to the profile picker.

## 0.5.1

- Profile JSON decoder accepts hand-written files that omit `id`, `autoFor` or
  `mappings`; missing fields get safe defaults.
- Version bump to exercise the Sparkle update path from 0.5.0 → 0.5.1.

## 0.5.0

- Export/import profiles as versioned JSON.
- Import from link: `mackey68://import?url=https://…`.
- Built-in presets and community samples in `presets/`.
- Sparkle auto-update with signed appcast.
- GitHub Actions CI and tagged release workflow.
- Developer ID/notarize scripts and Homebrew cask.
- Legal/trademark disclaimer and About dialog.

## 0.4.0

- Layout remembered per keyboard model (VID:PID + product/manufacturer).
- Detection table for Keychron, Akko, FL-Esports, Royal Kludge, Logitech,
  Razer, Corsair and GMMK boards.

## 0.3.0

- First-run 4-step guide.
- Auto-add keyboards on plug/unplug with detected layout.

## 0.2.0

- 68%, TKL and full-size drawn layouts.
- Multiple managed keyboards.
- `mackey layouts` and layout column in `mackey list`.

## 0.1.0

- Initial menu-bar app, per-key remapping, per-app profiles, VI/EN UI, DMG.
