# MenuTerm

A terminal emulator that integrates seamlessly with macOS notch.

## Building

使用构建脚本（推荐）：
```bash
./build.sh
```

或直接使用 xcodebuild：
```bash
xcodebuild -project MenuTerm.xcodeproj -scheme MenuTerm -configuration Debug \
  CONFIGURATION_BUILD_DIR=build/Debug \
  build
```

Clean build:
```bash
xcodebuild -project MenuTerm.xcodeproj -scheme MenuTerm -configuration Debug \
  CONFIGURATION_BUILD_DIR=build/Debug \
  clean build
```

Build output: `build/Debug/MenuTerm.app`

## App Icon

The app icon now uses the `logo.icon` Icon Composer document instead of a
legacy `AppIcon.appiconset`, so Xcode can render the macOS icon using the
current system icon pipeline.
