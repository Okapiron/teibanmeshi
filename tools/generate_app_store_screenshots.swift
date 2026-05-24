import AppKit
import CoreGraphics

struct ScreenshotSpec {
    let inputPath: String
    let outputName: String
    let title: String
    let subtitle: String
}

let outputDirectory = URL(fileURLWithPath: "/Users/hiroki/Projects/定番メシ/docs/app-store-screenshots", isDirectory: true)

let specs = [
    ScreenshotSpec(
        inputPath: "/Users/hiroki/Downloads/IMG_1827.PNG",
        outputName: "01-home.png",
        title: "いつもの注文を、すぐ思い出す",
        subtitle: "よく行く店にすばやくアクセス"
    ),
    ScreenshotSpec(
        inputPath: "/Users/hiroki/Downloads/IMG_1830.PNG",
        outputName: "02-shop-list.png",
        title: "登録した店を、さっと探せる",
        subtitle: "五十音順・追加順で見つけやすく"
    ),
    ScreenshotSpec(
        inputPath: "/Users/hiroki/Downloads/IMG_1829.PNG",
        outputName: "03-shop-detail.png",
        title: "定番・次試す・試した注文を整理",
        subtitle: "注文前に迷わずチェック"
    )
]

let canvasWidth = 1290
let canvasHeight = 2796
let statusCropTop = 142
let screenCornerRadius: CGFloat = 66
let frameCornerRadius: CGFloat = 86

let colorSpace = CGColorSpaceCreateDeviceRGB()

func cgImage(from path: String) -> CGImage {
    guard let image = NSImage(contentsOfFile: path),
          let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let cgImage = bitmap.cgImage else {
        fatalError("Could not load image at \(path)")
    }
    return cgImage
}

func drawRoundedRect(_ rect: CGRect, radius: CGFloat, in context: CGContext) {
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    context.addPath(path)
}

func drawText(_ text: String, rect: CGRect, fontSize: CGFloat, weight: NSFont.Weight, color: NSColor, alignment: NSTextAlignment = .center) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    paragraph.lineBreakMode = .byWordWrapping

    let font = NSFont.systemFont(ofSize: fontSize, weight: weight)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ]

    let string = NSAttributedString(string: text, attributes: attributes)
    string.draw(with: rect)
}

func fittedFontSize(for text: String, maxSize: CGFloat, minSize: CGFloat, weight: NSFont.Weight, maxWidth: CGFloat) -> CGFloat {
    var size = maxSize

    while size > minSize {
        let font = NSFont.systemFont(ofSize: size, weight: weight)
        let width = (text as NSString).size(withAttributes: [.font: font]).width
        if width <= maxWidth {
            return size
        }
        size -= 1
    }

    return minSize
}

func drawSingleLineText(_ text: String, rect: CGRect, maxFontSize: CGFloat, minFontSize: CGFloat, weight: NSFont.Weight, color: NSColor) {
    let fontSize = fittedFontSize(for: text, maxSize: maxFontSize, minSize: minFontSize, weight: weight, maxWidth: rect.width)
    let font = NSFont.systemFont(ofSize: fontSize, weight: weight)
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.lineBreakMode = .byClipping

    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ]

    let textSize = (text as NSString).size(withAttributes: attributes)
    let drawRect = CGRect(
        x: rect.minX,
        y: rect.minY + max(0, (rect.height - textSize.height) / 2),
        width: rect.width,
        height: textSize.height + 8
    )
    (text as NSString).draw(with: drawRect, options: [.usesLineFragmentOrigin], attributes: attributes)
}

func drawBackgroundAccents(in context: CGContext) {
    let warmPanel = CGRect(x: -90, y: canvasHeight - 745, width: canvasWidth + 180, height: 600)
    context.setFillColor(NSColor(red: 1.0, green: 0.86, blue: 0.57, alpha: 0.22).cgColor)
    drawRoundedRect(warmPanel, radius: 80, in: context)
    context.fillPath()

    context.setStrokeColor(NSColor(red: 0.86, green: 0.29, blue: 0.06, alpha: 0.13).cgColor)
    context.setLineWidth(30)
    context.setLineCap(.round)
    for offset in stride(from: -140, through: canvasWidth + 220, by: 210) {
        context.move(to: CGPoint(x: offset, y: canvasHeight - 660))
        context.addLine(to: CGPoint(x: offset + 310, y: canvasHeight - 260))
        context.strokePath()
    }

    context.setFillColor(NSColor(red: 0.86, green: 0.29, blue: 0.06, alpha: 0.10).cgColor)
    drawRoundedRect(CGRect(x: 72, y: 430, width: 190, height: 28), radius: 14, in: context)
    context.fillPath()
    drawRoundedRect(CGRect(x: canvasWidth - 300, y: 366, width: 228, height: 28), radius: 14, in: context)
    context.fillPath()
}

func render(_ spec: ScreenshotSpec) {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: canvasWidth,
        pixelsHigh: canvasHeight,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

    guard let context = NSGraphicsContext.current?.cgContext else {
        fatalError("Could not create graphics context")
    }

    context.setFillColor(NSColor(red: 1.0, green: 0.965, blue: 0.88, alpha: 1).cgColor)
    context.fill(CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
    drawBackgroundAccents(in: context)

    let titleColor = NSColor(red: 0.20, green: 0.15, blue: 0.10, alpha: 1)
    let subtitleColor = NSColor(red: 0.46, green: 0.42, blue: 0.35, alpha: 1)
    drawSingleLineText(spec.title, rect: CGRect(x: 60, y: canvasHeight - 330, width: canvasWidth - 120, height: 132), maxFontSize: 84, minFontSize: 58, weight: .heavy, color: titleColor)
    drawSingleLineText(spec.subtitle, rect: CGRect(x: 86, y: canvasHeight - 435, width: canvasWidth - 172, height: 84), maxFontSize: 50, minFontSize: 40, weight: .semibold, color: subtitleColor)

    let original = cgImage(from: spec.inputPath)
    let croppedHeight = original.height - statusCropTop
    guard let cropped = original.cropping(to: CGRect(x: 0, y: statusCropTop, width: original.width, height: croppedHeight)) else {
        fatalError("Could not crop screenshot")
    }

    let screenWidth: CGFloat = 872
    let screenHeight = screenWidth * CGFloat(cropped.height) / CGFloat(cropped.width)
    let screenRect = CGRect(
        x: (CGFloat(canvasWidth) - screenWidth) / 2,
        y: 500,
        width: screenWidth,
        height: screenHeight
    )
    let framePadding: CGFloat = 28
    let frameRect = screenRect.insetBy(dx: -framePadding, dy: -framePadding)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -20), blur: 38, color: NSColor.black.withAlphaComponent(0.18).cgColor)
    context.setFillColor(NSColor(red: 0.07, green: 0.065, blue: 0.06, alpha: 1).cgColor)
    drawRoundedRect(frameRect, radius: frameCornerRadius, in: context)
    context.fillPath()
    context.restoreGState()

    context.setFillColor(NSColor.black.cgColor)
    drawRoundedRect(frameRect.insetBy(dx: 8, dy: 8), radius: frameCornerRadius - 8, in: context)
    context.fillPath()

    context.saveGState()
    drawRoundedRect(screenRect, radius: screenCornerRadius, in: context)
    context.clip()
    context.interpolationQuality = .high
    context.draw(cropped, in: screenRect)
    context.restoreGState()

    let speakerRect = CGRect(x: CGFloat(canvasWidth) / 2 - 78, y: frameRect.maxY - 35, width: 156, height: 13)
    context.setFillColor(NSColor.black.withAlphaComponent(0.50).cgColor)
    drawRoundedRect(speakerRect, radius: 6.5, in: context)
    context.fillPath()

    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Could not create PNG data")
    }

    let outputURL = outputDirectory.appendingPathComponent(spec.outputName)
    do {
        try png.write(to: outputURL)
        print("Wrote \(outputURL.path)")
    } catch {
        fatalError("Could not write \(outputURL.path): \(error)")
    }
}

for spec in specs {
    render(spec)
}
