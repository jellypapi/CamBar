import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let docs = root.appendingPathComponent("docs")
let resources = root.appendingPathComponent("CamBar/Resources")
let iconset = root.appendingPathComponent("build/AppIcon.iconset")

try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
try FileManager.default.removeItemIfExists(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func writePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "CamBarAssetGeneration", code: 1)
    }
    try png.write(to: url)
}

func roundedRect(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let scale = size / 1024
    let bounds = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    bounds.fill()

    let tile = bounds.insetBy(dx: 86 * scale, dy: 86 * scale)
    let tilePath = roundedRect(tile, radius: 210 * scale)
    let bg = NSGradient(colors: [
        NSColor(calibratedRed: 0.06, green: 0.13, blue: 0.10, alpha: 1),
        NSColor(calibratedRed: 0.12, green: 0.23, blue: 0.18, alpha: 1)
    ])
    bg?.draw(in: tilePath, angle: -35)

    NSColor(calibratedRed: 0.42, green: 0.92, blue: 0.58, alpha: 0.92).setStroke()
    tilePath.lineWidth = 22 * scale
    tilePath.stroke()

    let menuBar = NSRect(x: 196 * scale, y: 706 * scale, width: 632 * scale, height: 86 * scale)
    NSColor.white.withAlphaComponent(0.18).setFill()
    roundedRect(menuBar, radius: 43 * scale).fill()

    let faceRect = NSRect(x: 358 * scale, y: 328 * scale, width: 308 * scale, height: 308 * scale)
    NSColor.white.setStroke()
    let face = NSBezierPath(ovalIn: faceRect)
    face.lineWidth = 34 * scale
    face.stroke()

    let curl = NSBezierPath()
    curl.move(to: NSPoint(x: 506 * scale, y: 660 * scale))
    curl.curve(
        to: NSPoint(x: 588 * scale, y: 662 * scale),
        controlPoint1: NSPoint(x: 514 * scale, y: 728 * scale),
        controlPoint2: NSPoint(x: 622 * scale, y: 714 * scale)
    )
    curl.lineWidth = 32 * scale
    curl.lineCapStyle = .round
    curl.stroke()

    NSColor.white.setFill()
    NSBezierPath(ovalIn: NSRect(x: 444 * scale, y: 474 * scale, width: 36 * scale, height: 36 * scale)).fill()
    NSBezierPath(ovalIn: NSRect(x: 544 * scale, y: 474 * scale, width: 36 * scale, height: 36 * scale)).fill()

    let mouth = NSBezierPath()
    mouth.move(to: NSPoint(x: 448 * scale, y: 424 * scale))
    mouth.curve(
        to: NSPoint(x: 576 * scale, y: 424 * scale),
        controlPoint1: NSPoint(x: 480 * scale, y: 378 * scale),
        controlPoint2: NSPoint(x: 544 * scale, y: 378 * scale)
    )
    mouth.lineWidth = 26 * scale
    mouth.lineCapStyle = .round
    mouth.stroke()

    NSColor(calibratedRed: 0.29, green: 0.96, blue: 0.45, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: 656 * scale, y: 280 * scale, width: 106 * scale, height: 106 * scale)).fill()

    image.unlockFocus()
    return image
}

func drawReadmePreview() -> NSImage {
    let size = NSSize(width: 1440, height: 920)
    let image = NSImage(size: size)
    image.lockFocus()

    let bounds = NSRect(origin: .zero, size: size)
    let bg = NSGradient(colors: [
        NSColor(calibratedRed: 0.92, green: 0.97, blue: 0.93, alpha: 1),
        NSColor(calibratedRed: 0.86, green: 0.92, blue: 0.89, alpha: 1)
    ])
    bg?.draw(in: bounds, angle: -25)

    let menu = NSRect(x: 0, y: 820, width: 1440, height: 100)
    NSColor(calibratedRed: 0.04, green: 0.52, blue: 0.24, alpha: 1).setFill()
    menu.fill()
    NSColor.white.withAlphaComponent(0.92).set()
    let menuAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 34, weight: .semibold),
        .foregroundColor: NSColor.white
    ]
    "CamBar".draw(at: NSPoint(x: 72, y: 852), withAttributes: menuAttributes)

    let iconPositions: [CGFloat] = [910, 986, 1062, 1138, 1214]
    for x in iconPositions {
        NSColor.white.withAlphaComponent(0.86).setFill()
        NSBezierPath(ovalIn: NSRect(x: x, y: 848, width: 42, height: 42)).fill()
    }
    NSColor.white.withAlphaComponent(0.22).setFill()
    roundedRect(NSRect(x: 890, y: 833, width: 82, height: 70), radius: 35).fill()

    let panel = NSRect(x: 230, y: 94, width: 980, height: 704)
    let panelPath = roundedRect(panel, radius: 34)
    NSColor(calibratedRed: 0.90, green: 0.95, blue: 0.91, alpha: 0.88).setFill()
    panelPath.fill()
    NSColor.black.withAlphaComponent(0.16).setStroke()
    panelPath.lineWidth = 2
    panelPath.stroke()

    let tabs = NSRect(x: 268, y: 726, width: 824, height: 58)
    NSColor.white.withAlphaComponent(0.40).setFill()
    roundedRect(tabs, radius: 15).fill()
    NSColor.black.withAlphaComponent(0.07).setFill()
    roundedRect(NSRect(x: 272, y: 730, width: 404, height: 50), radius: 13).fill()

    let tabAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 27, weight: .semibold),
        .foregroundColor: NSColor(calibratedWhite: 0.12, alpha: 1)
    ]
    "CAM1".draw(at: NSPoint(x: 430, y: 742), withAttributes: tabAttributes)
    "CAM2".draw(at: NSPoint(x: 836, y: 742), withAttributes: tabAttributes)

    NSColor.black.withAlphaComponent(0.12).setFill()
    roundedRect(NSRect(x: 1110, y: 726, width: 62, height: 58), radius: 15).fill()
    let plusAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 36, weight: .regular),
        .foregroundColor: NSColor(calibratedWhite: 0.12, alpha: 1)
    ]
    "+".draw(at: NSPoint(x: 1130, y: 732), withAttributes: plusAttributes)

    let video = NSRect(x: 268, y: 310, width: 904, height: 390)
    let videoPath = roundedRect(video, radius: 18)
    let videoBg = NSGradient(colors: [
        NSColor(calibratedRed: 0.19, green: 0.23, blue: 0.21, alpha: 1),
        NSColor(calibratedRed: 0.08, green: 0.12, blue: 0.11, alpha: 1)
    ])
    videoBg?.draw(in: videoPath, angle: 35)

    NSColor.white.withAlphaComponent(0.20).setStroke()
    videoPath.lineWidth = 2
    videoPath.stroke()

    let liveAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedDigitSystemFont(ofSize: 24, weight: .medium),
        .foregroundColor: NSColor.white.withAlphaComponent(0.70)
    ]
    "LIVE PREVIEW".draw(at: NSPoint(x: 302, y: 648), withAttributes: liveAttributes)

    NSColor.white.withAlphaComponent(0.10).setFill()
    roundedRect(NSRect(x: 420, y: 430, width: 600, height: 120), radius: 60).fill()
    NSColor.white.withAlphaComponent(0.22).setStroke()
    roundedRect(NSRect(x: 468, y: 458, width: 504, height: 64), radius: 32).stroke()

    let url = NSRect(x: 268, y: 242, width: 904, height: 48)
    NSColor.white.withAlphaComponent(0.82).setFill()
    roundedRect(url, radius: 13).fill()
    let urlAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 24, weight: .regular),
        .foregroundColor: NSColor(calibratedWhite: 0.12, alpha: 1)
    ]
    "rtsp://user:password@192.168.0.45:554/stream1".draw(at: NSPoint(x: 290, y: 253), withAttributes: urlAttributes)

    let statusAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 24, weight: .medium),
        .foregroundColor: NSColor(calibratedWhite: 0.44, alpha: 1)
    ]
    "Playing CAM1.".draw(at: NSPoint(x: 270, y: 200), withAttributes: statusAttributes)

    for (i, symbol) in ["▶", "◼", "↻"].enumerated() {
        let x = 268 + CGFloat(i) * 74
        NSColor.black.withAlphaComponent(0.08).setFill()
        roundedRect(NSRect(x: x, y: 138, width: 58, height: 48), radius: 12).fill()
        let attr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 25, weight: .medium),
            .foregroundColor: NSColor(calibratedWhite: 0.12, alpha: 1)
        ]
        symbol.draw(at: NSPoint(x: x + 18, y: 148), withAttributes: attr)
    }
    NSColor.black.withAlphaComponent(0.10).setFill()
    roundedRect(NSRect(x: 532, y: 154, width: 360, height: 16), radius: 8).fill()
    NSColor(calibratedRed: 0.12, green: 0.70, blue: 0.34, alpha: 0.9).setFill()
    roundedRect(NSRect(x: 532, y: 154, width: 260, height: 16), radius: 8).fill()

    let titleAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 52, weight: .bold),
        .foregroundColor: NSColor(calibratedWhite: 0.08, alpha: 1)
    ]
    "Menu bar RTSP camera preview".draw(at: NSPoint(x: 230, y: 28), withAttributes: titleAttributes)

    image.unlockFocus()
    return image
}

try writePNG(drawReadmePreview(), to: docs.appendingPathComponent("readme-preview.png"))

let iconSizes: [(String, CGFloat)] = [
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

for (name, size) in iconSizes {
    try writePNG(drawIcon(size: size), to: iconset.appendingPathComponent(name))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = [
    "-c", "icns",
    iconset.path,
    "-o", resources.appendingPathComponent("AppIcon.icns").path
]
try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
    throw NSError(domain: "CamBarAssetGeneration", code: Int(process.terminationStatus))
}

private extension FileManager {
    func removeItemIfExists(at url: URL) throws {
        if fileExists(atPath: url.path) {
            try removeItem(at: url)
        }
    }
}
