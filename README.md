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

## 滚动与布局回归测试

```bash
./Tests/run-scroll-tests.sh
# 已运行 ./build.sh 时可跳过重复构建
./Tests/run-scroll-tests.sh --skip-build
```

测试在进程内模拟鼠标和触摸板事件，覆盖窗口事件转发、历史回滚、鼠标上报、
全屏程序的方向键回退，以及触摸板小幅移动和惯性滚动；不需要辅助功能权限。
布局测试验证不同窗口宽度、字号及全屏模式下的左右内容边距、末列命中和隐藏滚动条占位。

真机验证：
- 运行 `seq 1 200`，用滚轮或双指上下滚动查看历史输出。
- 运行 `seq 1 200 | less`，确认全屏分页器可上下滚动，按 `q` 退出。
- 在启用鼠标支持的 TUI（例如 Vim 中执行 `:set mouse=a`）中确认滚动由程序处理。
- 调整窗口宽度和字号，确认 TUI 的左右边框留白一致，右侧滚动条随内容末列对齐。

## GitHub Releases

This repository can publish an unsigned macOS app bundle to GitHub Releases.

- Trigger: push a tag like `v1.0.0`, or run the `Release` workflow manually.
- Manual runs derive the tag from `MARKETING_VERSION` in `project.yml`, for example `1.0.0` -> `v1.0.0`.
- Output: `MenuTerm-<tag>-macos-unsigned.zip`
- Extra file: `MenuTerm-<tag>-macos-unsigned.zip.sha256`

Because the release artifact is unsigned and not notarized, macOS may warn on first launch. This flow is intended for internal distribution or technically capable users, not for general public release.

## Features

- 适配 macOS 刘海屏的终端模拟器
- 全局快捷键 `Ctrl + `` 切换显示/隐藏
- 失去焦点自动隐藏
- 鼠标滚轮和触摸板双指滚动，支持历史回滚及终端内交互程序
- 支持浅色/深色主题
- 可调节高度和透明度（设置窗口：`Cmd + ,`）

## App Icon

`logo.icon` is the Icon Composer source used by newer Xcode versions.
`MenuTerm/Assets.xcassets/logo.appiconset` contains a checked-in PNG fallback
with the same name for older Xcode versions (including Xcode 15.4 on the
`macos-14` release runner). Both build paths produce a compiled app icon.

After changing the Icon Composer document, regenerate the fallback on a Mac
with Icon Composer installed:

```bash
./scripts/generate-app-icon.sh
```

The release workflow validates the icon metadata and decodes the packaged
`.icns` before publishing. To run the same check locally:

```bash
./scripts/verify-app-icon.sh build/Release/MenuTerm.app
```
