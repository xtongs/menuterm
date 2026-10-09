#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Build first with ./build.sh (or run this script without --skip-build).
if [[ "${1:-}" != "--skip-build" ]]; then
    ./build.sh
fi
products="$PWD/build/DerivedData/Build/Products/Debug"
for test in ScrollWheelTests TerminalLayoutTests; do
    binary="$PWD/build/$test"
    xcrun swiftc -swift-version 5 -I "$products" \
        MenuTerm/Terminal/IMEAwareTerminalView.swift \
        MenuTerm/Terminal/TerminalViewController.swift \
        MenuTerm/Window/NotchPanel.swift \
        MenuTerm/Window/NotchWindowController.swift \
        MenuTerm/UI/NotchShapeView.swift \
        MenuTerm/Helpers/AppSettings.swift \
        MenuTerm/Helpers/NotchGeometry.swift \
        "Tests/$test.swift" \
        "$products/SwiftTerm.o" -o "$binary"
    "$binary"
done
