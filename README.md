# plain texts stickies

A tiny native macOS sticky note app. It keeps pasted content as plain system-font text, stripping rich text formatting.

## Install

Download `plain-texts-stickies.dmg` from GitHub Releases, open it, then drag `plain texts stickies.app` to `Applications`.

This build is ad-hoc signed but not Apple-notarized. On first launch, macOS may require right click -> Open.

## Build

```bash
./build.sh
```

## Package DMG

```bash
./package_dmg.sh
```

The DMG is created at `build/plain-texts-stickies.dmg`.

