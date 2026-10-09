#!/bin/bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 path/to/MenuTerm.app" >&2
    exit 1
fi
app="$1"
script_dir="$(cd "$(dirname "$0")" && pwd)"

# An arm64 linker signature alone does not seal the enclosing app bundle.
# Require the resource envelope as well as a valid signature over the bundle.
if [[ ! -s "$app/Contents/_CodeSignature/CodeResources" ]]; then
    echo "Release validation failed: missing app bundle resource signature" >&2
    exit 1
fi
codesign --verify --deep --strict --verbose=2 "$app"
"$script_dir/verify-app-icon.sh" "$app"
echo "Validated release app integrity: $app"
echo "Note: signature integrity does not imply Developer ID trust or Apple notarization."
