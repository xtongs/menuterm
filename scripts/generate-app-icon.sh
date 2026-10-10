#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Keep the legacy PNG fallback flat, with its own rounded tile and macOS margins.
# Do not resize an ictool preview: its baked glass/mask produces side seams when
# newer macOS versions apply the legacy-icon treatment again.
output="MenuTerm/Assets.xcassets/logo.appiconset"
xcrun swift scripts/GenerateAppIcon.swift logo.icon "$output"
echo "Regenerated $output from logo.icon/Assets (without baked material effects)"
