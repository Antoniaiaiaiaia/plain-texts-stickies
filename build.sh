#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/build/plain texts stickies.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
ICONSET="$ROOT/build/AppIcon.iconset"

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"
cp "$ROOT/Info.plist" "$CONTENTS/Info.plist"
python3 "$ROOT/Scripts/make_icon.py" "$ICONSET"
iconutil -c icns "$ICONSET" -o "$RESOURCES/AppIcon.icns"

swiftc "$ROOT/Sources/PlainTextsStickies/main.swift" \
  -framework AppKit \
  -o "$MACOS/PlainTextsStickies"

echo "$APP"
