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

This repository publishes ad-hoc signed macOS app bundles to GitHub Releases.
The bundle signature seals the executable, Info.plist, and resources; it is
**not** a Developer ID signature and the app is **not notarized by Apple**.

- Trigger: push a tag like `v1.0.0`, or run the `Release` workflow manually.
- Manual runs derive the tag from `MARKETING_VERSION` in `project.yml`, for example `1.0.0` -> `v1.0.0`.
- Output: `MenuTerm-<tag>-macos-adhoc.zip`
- Extra file: `MenuTerm-<tag>-macos-adhoc.zip.sha256`
- CI verifies the bundle signature and app icon before packaging and after extracting the ZIP.

### 首次打开下载的应用

临时签名只校验应用包完整性，不提供 Apple 信任或公证。macOS 仍可能阻止首次启动；
此发布方式适合信任本项目的用户，并不等同于正式签名、公证的发行方式。

1. 从本仓库 Release 下载 ZIP 和 `.sha256` 文件。在同一目录执行
   `shasum -a 256 -c MenuTerm-<tag>-macos-adhoc.zip.sha256`，确认校验通过。
2. 解压并将 `MenuTerm.app` 放入 `/Applications`。
3. 验证应用包：`codesign --verify --deep --strict --verbose=2 /Applications/MenuTerm.app`。
   如果失败，请不要跳过校验，重新下载或反馈问题。
4. 尝试打开，再到「系统设置 → 隐私与安全性」选择「仍要打开」（如有）。
   如果仍被阻止，且你确认来源并信任该应用，可以仅移除这份应用的下载隔离标记：

   ```bash
   xattr -dr com.apple.quarantine /Applications/MenuTerm.app
   open /Applications/MenuTerm.app
   ```

这会绕过该应用的首次下载隔离检查，但不会关闭整个系统的 Gatekeeper。不要对未知来源的应用执行。
要实现下载后无需手动放行，需要配置有效的 Developer ID Application 证书和 Apple 公证凭据。

### 旧版 v1.0.8 的“已损坏”提示

旧版 CI 禁用了应用签名，ARM 链接器只给可执行文件添加临时签名，没有签署应用包资源，
因此会报 `code has no resources but signature indicates they must be present`。
如果必须使用这份旧版、且已确认来自本仓库，可以先本地重签，再移除这份应用的隔离标记：

```bash
APP="/Applications/MenuTerm.app"
codesign --force --sign - --timestamp=none "$APP" &&
codesign --verify --deep --strict "$APP" &&
xattr -dr com.apple.quarantine "$APP" &&
open "$APP"
```

重签不会证明原下载内容可信，也不等同于 Apple 公证；不要用它跳过未知文件的完整性失败。

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
