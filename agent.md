# plain texts stickies

## What It Is

A native macOS sticky notes app inspired by Stickies. It keeps the familiar floating note workflow and forces pasted or dropped content to become plain text.

## How To Run

Run `./build.sh`, then open `build/plain texts stickies.app`.

## Key Files

- `Sources/PlainTextsStickies/main.swift` — AppKit app, note windows, autosave, and plain-text paste handling.
- `Info.plist` — macOS app bundle metadata.
- `Scripts/make_icon.py` — generates the flat sticky-note app icon.
- `build.sh` — creates `build/plain texts stickies.app`.
- `package_dmg.sh` — creates `build/plain-texts-stickies.dmg` for GitHub Releases.

## Architecture

Notes are stored in `UserDefaults` under `plain-texts-stickies.notes.v1`. Each note is a small JSON object with id, text, position, and size. Editing uses `NSTextView` with rich text disabled, and paste/drop reads only the macOS plain string pasteboard type.

## Development Notes

- Keep this app dependency-free unless AppKit cannot cover a required interaction.
- Keep paste behavior in `PlainTextView` so every note shares the same plain-text-only path.
- Do not add rich text controls; that would reintroduce the formatting problem this app avoids.
