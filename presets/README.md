# Profile presets

Shareable MacKey68 profiles. Import in the app: **share icon → Import profile…**, or
open a link:

```
mackey68://import?url=https://raw.githubusercontent.com/thdat-vu/MacKey68/main/presets/league.json
```

## Format

```json
{
  "format": "mackey68.profile",
  "version": 1,
  "profile": {
    "id": "unique-id",
    "name": "Human name",
    "autoFor": ["com.example.app"],
    "mappings": [
      { "from": "CapsLock", "to": "Grave" }
    ]
  },
  "keyboard": "optional model hint"
}
```

A bare `profile` object (without the wrapper) is also accepted.

## Included

| File | What it does |
|---|---|
| `macbook.json` | Alt ↔ Command next to Space |
| `league.json` | Caps Lock → `` ` ``, Alt stays next to Space |
| `coding.json` | MacBook layout + Caps Lock → Escape |
| `caps-escape.json` | Caps Lock → Escape only |
| `no-caps.json` | Caps Lock → Control |
| `caps-ctrl-swap.json` | Swap Caps Lock and left Control |
| `right-alt-cmd.json` | Right Alt → Right Command |

Keep ids lowercase and stable. Imported profiles get a new id if it already exists, so
sharing will not overwrite someone's local edits.
