#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Only regenerating the checked-in PNG fallback requires Icon Composer.
# Building it via Assets.xcassets works with Xcode 15 and later.
developer_dir="$(xcode-select -p)"
ictool="$developer_dir/../Applications/Icon Composer.app/Contents/Executables/ictool"
if [[ ! -x "$ictool" ]]; then
    echo "Select an Xcode installation with Icon Composer to regenerate the icon." >&2
    exit 1
fi

output="MenuTerm/Assets.xcassets/logo.appiconset"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$output"
"$ictool" logo.icon --export-image --output-file "$work/logo.png" \
    --platform macOS --rendition Default --width 1024 --height 1024 --scale 1

for size in 16 32 128 256 512; do
    for scale in 1 2; do
        suffix=""
        if [[ "$scale" == 2 ]]; then suffix="@2x"; fi
        pixels=$((size * scale))
        sips -z "$pixels" "$pixels" "$work/logo.png" \
            --out "$output/icon_${size}x${size}${suffix}.png" >/dev/null
    done
done

echo "Regenerated $output from logo.icon"
