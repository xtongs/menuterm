#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ $# -gt 1 ]]; then
    echo "Usage: $0 [path/to/MenuTerm.app]" >&2
    exit 1
fi
mkdir -p build/icon-tests
xcrun swiftc Tests/AppIconTests.swift -o build/icon-tests/AppIconTests
build/icon-tests/AppIconTests MenuTerm/Assets.xcassets/logo.appiconset build/icon-tests "$@"
