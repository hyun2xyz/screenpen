#!/usr/bin/env swift

import AppKit
import Foundation

enum ArtworkError: Error, CustomStringConvertible {
    case usage
    case bitmapCreation
    case pngEncoding

    var description: String {
        switch self {
        case .usage:
            "Usage: generate-release-artwork.swift <output-directory>"
        case .bitmapCreation:
            "Could not create a bitmap canvas."
        case .pngEncoding:
            "Could not encode artwork as PNG."
        }
    }
}

func renderPNG(
    width: Int,
    height: Int,
    draw: (CGRect) -> Void
) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw ArtworkError.bitmapCreation
    }

    bitmap.size = NSSize(width: width, height: height)
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw ArtworkError.bitmapCreation
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    draw(CGRect(x: 0, y: 0, width: width, height: height))
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw ArtworkError.pngEncoding
    }
    return data
}

func drawAppIcon(in rect: CGRect) {
    NSColor.clear.setFill()
    rect.fill()

    let size = rect.width
    let tile = rect.insetBy(dx: size * 0.055, dy: size * 0.055)
    let tilePath = NSBezierPath(
        roundedRect: tile,
        xRadius: size * 0.22,
        yRadius: size * 0.22
    )

    NSGraphicsContext.saveGraphicsState()
    tilePath.addClip()
    NSGradient(colors: [
        NSColor(calibratedRed: 0.08, green: 0.12, blue: 0.20, alpha: 1),
        NSColor(calibratedRed: 0.12, green: 0.24, blue: 0.42, alpha: 1)
    ])?.draw(in: tile, angle: -45)
    NSGraphicsContext.restoreGraphicsState()

    tilePath.lineWidth = max(1, size * 0.012)
    NSColor.white.withAlphaComponent(0.18).setStroke()
    tilePath.stroke()

    let stroke = NSBezierPath()
    stroke.move(to: CGPoint(x: size * 0.24, y: size * 0.31))
    stroke.curve(
        to: CGPoint(x: size * 0.76, y: size * 0.68),
        controlPoint1: CGPoint(x: size * 0.40, y: size * 0.22),
        controlPoint2: CGPoint(x: size * 0.59, y: size * 0.76)
    )
    stroke.lineWidth = max(2, size * 0.055)
    stroke.lineCapStyle = .round
    NSColor(calibratedRed: 0.24, green: 0.67, blue: 1, alpha: 1).setStroke()
    stroke.stroke()

    let pen = NSBezierPath()
    pen.move(to: CGPoint(x: size * 0.35, y: size * 0.70))
    pen.line(to: CGPoint(x: size * 0.68, y: size * 0.37))
    pen.lineWidth = max(2, size * 0.075)
    pen.lineCapStyle = .round
    NSColor.white.setStroke()
    pen.stroke()

    let nib = NSBezierPath()
    nib.move(to: CGPoint(x: size * 0.66, y: size * 0.39))
    nib.line(to: CGPoint(x: size * 0.73, y: size * 0.31))
    nib.lineWidth = max(1.5, size * 0.038)
    nib.lineCapStyle = .round
    NSColor.white.withAlphaComponent(0.82).setStroke()
    nib.stroke()
}

func drawCenteredText(
    _ text: String,
    y: CGFloat,
    font: NSFont,
    color: NSColor,
    canvasWidth: CGFloat
) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color
    ]
    let size = (text as NSString).size(withAttributes: attributes)
    (text as NSString).draw(
        at: CGPoint(x: (canvasWidth - size.width) / 2, y: y),
        withAttributes: attributes
    )
}

func drawDMGBackground(in rect: CGRect) {
    NSGradient(colors: [
        NSColor(calibratedWhite: 0.97, alpha: 1),
        NSColor(calibratedWhite: 0.90, alpha: 1)
    ])?.draw(in: rect, angle: -90)

    drawCenteredText(
        "ScreenPen 설치",
        y: 350,
        font: .systemFont(ofSize: 27, weight: .semibold),
        color: NSColor(calibratedWhite: 0.12, alpha: 1),
        canvasWidth: rect.width
    )
    drawCenteredText(
        "ScreenPen를 Applications 폴더로 드래그하세요",
        y: 320,
        font: .systemFont(ofSize: 14, weight: .regular),
        color: NSColor(calibratedWhite: 0.38, alpha: 1),
        canvasWidth: rect.width
    )

    let arrow = NSBezierPath()
    arrow.move(to: CGPoint(x: 286, y: 190))
    arrow.line(to: CGPoint(x: 398, y: 190))
    arrow.lineWidth = 5
    arrow.lineCapStyle = .round
    NSColor(calibratedRed: 0.12, green: 0.48, blue: 0.86, alpha: 0.82).setStroke()
    arrow.stroke()

    let arrowHead = NSBezierPath()
    arrowHead.move(to: CGPoint(x: 384, y: 204))
    arrowHead.line(to: CGPoint(x: 402, y: 190))
    arrowHead.line(to: CGPoint(x: 384, y: 176))
    arrowHead.lineWidth = 5
    arrowHead.lineCapStyle = .round
    arrowHead.lineJoinStyle = .round
    NSColor(calibratedRed: 0.12, green: 0.48, blue: 0.86, alpha: 0.82).setStroke()
    arrowHead.stroke()

    let divider = NSBezierPath()
    divider.move(to: CGPoint(x: 72, y: 70))
    divider.line(to: CGPoint(x: 608, y: 70))
    divider.lineWidth = 1
    NSColor(calibratedWhite: 0.75, alpha: 0.55).setStroke()
    divider.stroke()

    drawCenteredText(
        "펜 · 형광펜 · 지우개 · 스포트라이트 · macOS 내장 확대",
        y: 42,
        font: .systemFont(ofSize: 10, weight: .medium),
        color: NSColor(calibratedWhite: 0.50, alpha: 1),
        canvasWidth: rect.width
    )
}

func main() throws {
    guard CommandLine.arguments.count == 2 else {
        throw ArtworkError.usage
    }

    let fileManager = FileManager.default
    let outputDirectory = URL(
        fileURLWithPath: CommandLine.arguments[1],
        isDirectory: true
    )
    let iconsetDirectory = outputDirectory
        .appendingPathComponent("ScreenPen.iconset", isDirectory: true)

    try fileManager.createDirectory(
        at: iconsetDirectory,
        withIntermediateDirectories: true
    )

    let iconVariants: [(String, Int)] = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024)
    ]

    for (fileName, pixelSize) in iconVariants {
        let data = try renderPNG(width: pixelSize, height: pixelSize) { rect in
            drawAppIcon(in: rect)
        }
        try data.write(to: iconsetDirectory.appendingPathComponent(fileName))
    }

    let background = try renderPNG(width: 680, height: 420) { rect in
        drawDMGBackground(in: rect)
    }
    try background.write(
        to: outputDirectory.appendingPathComponent("ScreenPen-dmg-background.png")
    )
}

do {
    try main()
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}
