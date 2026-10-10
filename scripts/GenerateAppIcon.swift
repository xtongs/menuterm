import AppKit

// Render the legacy icon from the artwork, NOT ictool's material preview.
// The preview has a full-bleed, pre-clipped glass edge. macOS's legacy-icon
// treatment clips/lights that edge again, producing short bright side seams.
// A flat rounded tile with standard macOS padding works on both old and new OSes.
private struct IconDocument: Decodable {
    struct Group: Decodable {
        struct Layer: Decodable {
            struct Position: Decodable {
                let scale: CGFloat
                let translation: [CGFloat]

                enum CodingKeys: String, CodingKey {
                    case scale
                    case translation = "translation-in-points"
                }
            }
            let imageName: String
            let hidden: Bool
            let position: Position

            enum CodingKeys: String, CodingKey {
                case imageName = "image-name"
                case hidden, position
            }
        }
        let layers: [Layer]
    }
    let groups: [Group]
}

private func generate(source: URL, output: URL) throws {
    let document = try JSONDecoder().decode(
        IconDocument.self, from: Data(contentsOf: source.appendingPathComponent("icon.json")))
    let layers = document.groups.flatMap(\.layers).filter { !$0.hidden }
    guard layers.count == 1, let layer = layers.first,
          layer.position.translation.count == 2,
          let artwork = NSImage(contentsOf: source.appendingPathComponent("Assets/\(layer.imageName)")) else {
        throw NSError(domain: "GenerateAppIcon", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Expected a single visible SVG layer with a two-coordinate position"
        ])
    }

    // 102 pt margins around an 820 pt tile on a 1024 pt canvas. Keep the
    // artwork's Icon Composer scale/position, but omit glass and bevels.
    let canvas: CGFloat = 1024
    let tile = NSRect(x: 102, y: 102, width: 820, height: 820)
    let artworkScale = layer.position.scale * tile.width / canvas
    let artworkSize = NSSize(width: artwork.size.width * artworkScale,
                             height: artwork.size.height * artworkScale)
    let artworkRect = NSRect(
        x: (canvas - artworkSize.width) / 2 + layer.position.translation[0] * tile.width / canvas,
        y: (canvas - artworkSize.height) / 2 - layer.position.translation[1] * tile.height / canvas,
        width: artworkSize.width, height: artworkSize.height)

    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    for size in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let pixels = size * scale
            // Supersample the vector artwork and the rounded mask together.
            let samples = pixels * 4
            let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: samples, pixelsHigh: samples,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
            let transform = NSAffineTransform()
            transform.scale(by: CGFloat(samples) / canvas)
            transform.concat()
            let shape = NSBezierPath(roundedRect: tile, xRadius: 184, yRadius: 184)
            // A conventional, soft black shadow for older macOS versions.
            // This is not a bevel or a bright/material edge.
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
            // NSShadow uses base-space units, not the artwork transform.
            let shadowScale = CGFloat(samples) / canvas
            shadow.shadowOffset = NSSize(width: 0, height: -10 * shadowScale)
            shadow.shadowBlurRadius = 18 * shadowScale
            shadow.set()
            NSColor.black.setFill()
            shape.fill()
            NSShadow().set()
            shape.addClip()
            artwork.draw(in: artworkRect, from: .zero, operation: .sourceOver, fraction: 1)
            NSGraphicsContext.restoreGraphicsState()

            let image = NSImage(size: NSSize(width: samples, height: samples))
            image.addRepresentation(bitmap)
            let result = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: result)
            NSGraphicsContext.current?.imageInterpolation = .high
            image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
                       from: .zero, operation: .copy, fraction: 1)
            NSGraphicsContext.restoreGraphicsState()

            // Preserve the artwork's cool-white appearance. Exact grayscale
            // is optimized to Gray by actool; macOS 27 treats that catalog icon
            // as a template and adds a white backing tile. An RGB off-white
            // glyph avoids that path without baking in any glass highlights.
            let data = result.bitmapData!
            for y in 0..<pixels {
                for x in 0..<pixels {
                    let offset = y * result.bytesPerRow + x * 4 // RGBA, alpha last
                    data[offset] = UInt8((Int(data[offset]) * 250 + 127) / 255)
                    data[offset + 1] = UInt8((Int(data[offset + 1]) * 251 + 127) / 255)
                }
            }

            let suffix = scale == 2 ? "@2x" : ""
            let filename = "icon_\(size)x\(size)\(suffix).png"
            guard let png = result.representation(using: .png, properties: [:]) else {
                throw NSError(domain: "GenerateAppIcon", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "Unable to encode \(filename)"
                ])
            }
            try png.write(to: output.appendingPathComponent(filename))
        }
    }
}

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: GenerateAppIcon.swift source.icon output.appiconset\n", stderr)
    exit(1)
}
do {
    try generate(source: URL(fileURLWithPath: CommandLine.arguments[1]),
                 output: URL(fileURLWithPath: CommandLine.arguments[2]))
} catch {
    fputs("App icon generation failed: \(error.localizedDescription)\n", stderr)
    exit(1)
}
