import AppKit

private enum TestError: Error, CustomStringConvertible {
    case failed(String)
    var description: String {
        switch self { case .failed(let message): return message }
    }
}

private func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw TestError.failed(message) }
}

private func bitmap(at url: URL) throws -> NSBitmapImageRep {
    guard let image = NSBitmapImageRep(data: try Data(contentsOf: url)) else {
        throw TestError.failed("Cannot decode \(url.path)")
    }
    return image
}

private func rgba(_ bitmap: NSBitmapImageRep, _ x: Int, _ y: Int) -> (CGFloat, CGFloat, CGFloat, CGFloat) {
    let color = bitmap.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
    return (color.redComponent, color.greenComponent, color.blueComponent, color.alphaComponent)
}

private func validateSources(_ assets: URL) throws {
    for size in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
            let image = try bitmap(at: assets.appendingPathComponent(name))
            let pixels = size * scale
            try require(image.pixelsWide == pixels && image.pixelsHigh == pixels,
                        "Wrong dimensions for \(name)")
            var glyphPixels = 0
            var hasRGBGlyph = false
            for y in 0..<pixels {
                for x in 0..<pixels {
                    let (r, g, b, a) = rgba(image, x, y)
                    let nx = CGFloat(x) / CGFloat(pixels)
                    let ny = CGFloat(y) / CGFloat(pixels)
                    // Leave room for filtering at small sizes. A full-bleed
                    // ictool preview fails this even if its corners are clear.
                    if nx < 0.05 || nx > 0.95 || ny < 0.05 || ny > 0.95 {
                        try require(a < 0.02, "Missing macOS transparent margins: \(name) at \(x),\(y)")
                    }
                    // No baked bevel/highlight outside the terminal glyph.
                    let inGlyph = nx > 0.15 && nx < 0.48 && ny > 0.18 && ny < 0.46
                    if a > 0.1 && !inGlyph {
                        try require(max(r, g, b) < 0.03, "Baked material/edge highlight in \(name)")
                    }
                    if inGlyph && min(r, g, b) * a > 0.5 {
                        glyphPixels += 1
                        if b - r > 0.005 { hasRGBGlyph = true }
                    }
                }
            }
            try require(glyphPixels > 0, "Missing terminal glyph: \(name)")
            try require(hasRGBGlyph, "Glyph must stay RGB, not a grayscale template: \(name)")
            let (_, _, _, alpha) = rgba(image, pixels / 2, pixels / 2)
            try require(alpha > 0.99, "Icon tile must be opaque: \(name)")
        }
    }
    print("PASS: all 10 PNGs have correct sizes, padding and flat edges")
}

private func run(_ executable: String, _ arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    try process.run()
    process.waitUntilExit()
    try require(process.terminationStatus == 0, "Command failed: \(executable)")
}

private func makeLegacyFixture(assets: URL, work: URL) throws -> URL {
    let fm = FileManager.default
    let app = work.appendingPathComponent("Legacy.app")
    let resources = app.appendingPathComponent("Contents/Resources")
    let executables = app.appendingPathComponent("Contents/MacOS")
    try fm.createDirectory(at: resources, withIntermediateDirectories: true)
    try fm.createDirectory(at: executables, withIntermediateDirectories: true)
    // Supply a valid executable so Launch Services doesn't overlay a prohibitory
    // badge. It is never launched. A unique path/ID avoids the system icon cache.
    let executable = executables.appendingPathComponent("probe")
    try Data(contentsOf: URL(fileURLWithPath: "/usr/bin/true")).write(to: executable)
    try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
    let plist: [String: Any] = [
        "CFBundleIdentifier": "com.menuterm.icontest.\(UUID().uuidString)",
        "CFBundleName": "Legacy", "CFBundleExecutable": "probe",
        "CFBundlePackageType": "APPL", "CFBundleVersion": "1",
        "CFBundleIconFile": "logo", "CFBundleIconName": "logo"
    ]
    try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        .write(to: app.appendingPathComponent("Contents/Info.plist"))
    let iconset = work.appendingPathComponent("legacy.iconset")
    try fm.createDirectory(at: iconset, withIntermediateDirectories: true)
    for file in try fm.contentsOfDirectory(at: assets, includingPropertiesForKeys: nil)
        where file.pathExtension == "png" {
        try fm.copyItem(at: file, to: iconset.appendingPathComponent(file.lastPathComponent))
    }
    try run("/usr/bin/iconutil", ["-c", "icns", iconset.path, "-o", resources.appendingPathComponent("logo.icns").path])
    return app
}

private func validateSystemIcon(app: URL, label: String, output: URL) throws {
    let icon = NSWorkspace.shared.icon(forFile: app.path)
    let os = ProcessInfo.processInfo.operatingSystemVersion
    // The numeric highlight limit covers the macOS 27 renderer where the bug
    // was reproduced. Other OSes still validate the sources and export previews;
    // their intentional lighting differs and must not cause false failures.
    let checkHighlights = os.majorVersion == 27
    for pixels in [512, 256, 128, 64] {
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        icon.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
                  from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        try bitmap.representation(using: .png, properties: [:])!
            .write(to: output.appendingPathComponent("\(label)-\(pixels).png"))

        if checkHighlights {
            for side in ["left", "right"] {
                let start = Int(CGFloat(pixels) * (side == "left" ? 0.08 : 0.87))
                let end = Int(CGFloat(pixels) * (side == "left" ? 0.13 : 0.92))
                var peak: CGFloat = 0
                for y in Int(CGFloat(pixels) * 0.28)..<Int(CGFloat(pixels) * 0.72) {
                    for x in start..<end {
                        let (r, g, b, a) = rgba(bitmap, x, y)
                        peak = max(peak, max(r, g, b) * a)
                    }
                }
                // The old icon reaches ~112/255; the corrected one ~38/255.
                try require(peak < 64.0 / 255.0,
                            "\(label) \(pixels)px: bright \(side) seam (\(Int(peak * 255))/255)")
            }
        }
    }
    print("PASS: \(label) system previews at 64/128/256/512px" +
          (checkHighlights ? ", no bright side seams" : " (seam threshold only applies to macOS 27)"))
}

guard (3...4).contains(CommandLine.arguments.count) else {
    fputs("Usage: AppIconTests assets.appiconset output-directory [MenuTerm.app]\n", stderr)
    exit(1)
}
let assets = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let work = FileManager.default.temporaryDirectory.appendingPathComponent("menuterm-icon-tests-\(UUID().uuidString)")
defer { try? FileManager.default.removeItem(at: work) }
do {
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    try validateSources(assets)
    let legacy = try makeLegacyFixture(assets: assets, work: work)
    try validateSystemIcon(app: legacy, label: "legacy-icns", output: output)

    // Exercise the real Xcode 15-style path too: Assets.car changes how macOS
    // recognizes legacy icon padding. An ICNS-only fixture cannot catch that.
    let catalog = work.appendingPathComponent("Legacy.xcassets")
    try FileManager.default.createDirectory(at: catalog, withIntermediateDirectories: true)
    try FileManager.default.copyItem(at: assets, to: catalog.appendingPathComponent("logo.appiconset"))
    let compiled = work.appendingPathComponent("Compiled.app")
    try FileManager.default.copyItem(at: legacy, to: compiled)
    try run("/usr/bin/xcrun", [
        "actool", catalog.path, "--compile", compiled.appendingPathComponent("Contents/Resources").path,
        "--platform", "macosx", "--minimum-deployment-target", "14.0", "--app-icon", "logo",
        "--output-partial-info-plist", work.appendingPathComponent("icon-info.plist").path
    ])
    try validateSystemIcon(app: compiled, label: "legacy-catalog", output: output)
    if CommandLine.arguments.count == 4 {
        let app = URL(fileURLWithPath: CommandLine.arguments[3])
        try require(FileManager.default.fileExists(atPath: app.appendingPathComponent("Contents/Info.plist").path),
                    "Missing app bundle: \(app.path)")
        let copy = work.appendingPathComponent("Built.app")
        try FileManager.default.copyItem(at: app, to: copy)
        try validateSystemIcon(app: copy, label: "built", output: output)
    }
} catch {
    fputs("FAIL: \(error)\n", stderr)
    exit(1)
}
