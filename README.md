# MenuTerm

A terminal emulator that integrates seamlessly with macOS notch.

## Building

### 使用构建脚本（推荐）

```bash
# 构建 Debug
./build.sh

# 构建 Release
./build.sh -c Release

# 清理并构建 Release
./build.sh -c Release -C

# 创建归档
./build.sh -c Release -a

# 查看帮助
./build.sh -h
```

### 环境变量

```bash
CONFIG=Release ./build.sh
CLEAN=true ./build.sh -c Release
ARCHIVE=true ./build.sh
```

### 直接使用 xcodebuild

```bash
xcodebuild -project MenuTerm.xcodeproj -scheme MenuTerm -configuration Debug build
```

### Build Output

| 配置 | 路径 |
|------|------|
| Debug | `build/Debug/MenuTerm.app` |
| Release | `build/Release/MenuTerm.app` |
| Archive | `build/MenuTerm.xcarchive` |

## Features

- 适配 macOS 刘海屏的终端模拟器
- 全局快捷键 `Ctrl + `` 切换显示/隐藏
- 失去焦点自动隐藏
- 支持浅色/深色主题
- 可调节高度和透明度（设置窗口：`Cmd + ,`）

## App Icon

The app icon now uses the `logo.icon` Icon Composer document instead of a
legacy `AppIcon.appiconset`, so Xcode can render the macOS icon using the
current system icon pipeline.
