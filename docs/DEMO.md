# Demo assets

`README.md` embeds `docs/demo.gif` and links to `docs/demo.mp4`.

## Regenerate

Sources are the window screenshots in `docs/screenshots/`:

- `demo-board.png` — 68-key board with remaps and coverage checkmarks
- `demo-tkl.png` — TKL layout
- `demo-keytest.png` — Key Test (coverage, tester, chatter)
- `demo-guide.png` — first-run guide

```bash
./scripts/make-demo.sh
```

Requirements: `ffmpeg` and Python 3 with Pillow:

```bash
python3 -m pip install --user pillow
```

The script renders six 1600×1000 slides (intro, four features, outro), builds a
19.9 s H.264 MP4 with cross-fades, and converts it to a 1000 px, 12 fps GIF.

## Capturing new screenshots

Use window capture so no desktop clutter appears:

```bash
screencapture -l <window-id> -o docs/screenshots/demo-board.png
```

Get the window id from `CGWindowListCopyWindowInfo` (or use `screencapture -i`).
Keep the originals at 2× Retina size; the script scales them down.

## Tips

- Keep the GIF under ~8 MB for GitHub README performance.
- Use English captions in the shared demo; the app itself is bilingual.
- Re-record when the header layout or Key Test changes.
