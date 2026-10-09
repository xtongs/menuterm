#!/bin/bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 path/to/MenuTerm.app" >&2
    exit 1
fi
app="$1"
plist="$app/Contents/Info.plist"
fail() { echo "App icon validation failed: $*" >&2; exit 1; }

[[ -f "$plist" ]] || fail "Missing $plist"
icon_name=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconName' "$plist" 2>/dev/null) || fail "Missing CFBundleIconName"
icon_file=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$plist" 2>/dev/null) || fail "Missing CFBundleIconFile"
[[ -n "$icon_name" && -n "$icon_file" ]] || fail "Empty icon metadata"
if [[ "$icon_file" != *.icns ]]; then icon_file="$icon_file.icns"; fi
icon_path="$app/Contents/Resources/$icon_file"
[[ -s "$icon_path" ]] || fail "Missing compiled icon: $icon_path"

# Decode the actual packaged icon, not just the source .icon document.
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
iconutil -c iconset "$icon_path" -o "$work/validated.iconset" || fail "Invalid ICNS data"
find "$work/validated.iconset" -name '*.png' -print -quit | grep -q . || fail "Icon has no image representations"
echo "Validated app icon '$icon_name': $icon_path"
