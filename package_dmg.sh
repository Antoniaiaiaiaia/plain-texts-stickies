#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/build/plain texts stickies.app"
STAGING="$ROOT/build/dmg"
DMG="$ROOT/build/plain-texts-stickies.dmg"

"$ROOT/build.sh" >/dev/null
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
ditto "$APP" "$STAGING/plain texts stickies.app"
ln -s /Applications "$STAGING/Applications"
codesign --force --deep --sign - "$STAGING/plain texts stickies.app" >/dev/null
hdiutil create -volname "plain texts stickies" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
echo "$DMG"

