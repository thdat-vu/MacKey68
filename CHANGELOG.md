# Changelog

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
