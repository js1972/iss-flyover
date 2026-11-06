import SwiftUI
import UIKit

/// Archive complication-sized bitmaps, not the full photos used by app cards.
/// SwiftUI's frame/scaledToFit changes layout but does not downsample the image.
enum ComplicationArtwork {
    static let pixelLimit = 72
    static let circularBackdrops = backdrops(width: 100, height: 100, circular: true)
    static let rectangularBackdrops = backdrops(width: 336, height: 144, circular: false)
    static let images: [String: CGImage] = {
        let names = WidgetPlanet.allCases.map(\.assetName) + ["WidgetISS", "FullMoon"]
        return Dictionary(uniqueKeysWithValues: names.compactMap { name in
            guard let source = UIImage(named: name)?.cgImage else { return nil }
            let ratio = min(1, Double(pixelLimit) / Double(max(source.width, source.height)))
            let width = max(1, Int((Double(source.width) * ratio).rounded()))
            let height = max(1, Int((Double(source.height) * ratio).rounded()))
            guard let context = CGContext(data: nil, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            context.interpolationQuality = .high
            context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
            guard let image = context.makeImage() else { return nil }
            return (name, image)
        })
    }()

    // Crop the real photos and bake only the contrast fades into a small bitmap.
    // Text remains native/live, and accented faces retain the same contrast.
    private static func backdrops(width: Int, height: Int, circular: Bool) -> [String: CGImage] {
        let names = WidgetPlanet.allCases.map(\.assetName) + ["WidgetISS", "FullMoon"]
        return Dictionary(uniqueKeysWithValues: names.compactMap { name in
            guard let source = UIImage(named: name)?.cgImage,
                  let context = CGContext(data: nil, width: width, height: height,
                    bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            let w = CGFloat(width), h = CGFloat(height)
            context.setFillColor(UIColor.black.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: w, height: h))
            let aspect = CGFloat(source.width) / CGFloat(source.height)
            let imageWidth: CGFloat
            // Fit Saturn's wide rings inside the circular slot, above its name.
            if name == "PlanetSaturn" { imageWidth = w * (circular ? 1.45 : 1.55) }
            else if name == "WidgetISS" { imageWidth = w * (circular ? 1.25 : 0.95) }
            else { imageWidth = h * (circular ? 0.74 : 1.05) * aspect }
            let imageHeight = imageWidth / aspect
            let centerX = w * (circular ? 0.5 : 0.66)
            let centerY = h * (circular ? (name == "PlanetSaturn" ? 0.65 : 0.73) : 0.52) // Core Graphics origin is bottom-left.
            context.interpolationQuality = .high
            context.draw(source, in: CGRect(x: centerX - imageWidth / 2, y: centerY - imageHeight / 2,
                                            width: imageWidth, height: imageHeight))
            let colors = (circular
                ? [UIColor.black.withAlphaComponent(0), .black.withAlphaComponent(0.12), .black]
                : [UIColor.black.withAlphaComponent(0.88), .black.withAlphaComponent(0.5), .black.withAlphaComponent(0)])
                .map(\.cgColor) as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.55, 1]) {
                context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: h),
                    end: circular ? CGPoint(x: 0, y: 0) : CGPoint(x: w * 0.8, y: h),
                    options: [.drawsAfterEndLocation])
            }
            guard let image = context.makeImage() else { return nil }
            return (name, image)
        })
    }
}

extension SkyEvent {
    var artworkAsset: String? {
        if kind == "iss" { return "WidgetISS" }
        if kind == "moon" { return "FullMoon" }
        return WidgetPlanet(event: self)?.assetName
    }
}

enum WidgetPlanet: String, CaseIterable {
    case mercury = "Mercury", venus = "Venus", mars = "Mars"
    case jupiter = "Jupiter", saturn = "Saturn"

    init?(event: SkyEvent) {
        guard event.kind == "planet" else { return nil }
        self.init(rawValue: event.body)
    }

    var assetName: String { "Planet" + rawValue }
}

struct WidgetArtworkBackground: View {
    var assetName: String
    var isISS: Bool
    var small: Bool

    var body: some View {
        GeometryReader { geometry in
            Image(assetName)
                .resizable()
                .aspectRatio(contentMode: isISS ? .fit : .fill)
                .frame(width: isISS ? (small ? 210 : 260) : (small ? 270 : 320), height: isISS ? 150 : (small ? 190 : 210))
                .position(x: geometry.size.width * (small ? 0.88 : 0.80), y: geometry.size.height * 0.47)
        }
        // Let the subject extend to the card edge and behind the labels. Fade the
        // left and lower edges to retain a dark reading surface for all text sizes.
        .mask {
            LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .white.opacity(0.2), location: 0.25), .init(color: .white, location: 0.85)], startPoint: .leading, endPoint: .trailing)
                .mask { LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .white, location: 0.25), .init(color: .white, location: 0.55), .init(color: .clear, location: 0.95)], startPoint: .top, endPoint: .bottom) }
        }
        .opacity(isISS ? 0.7 : assetName == "FullMoon" ? 0.65 : 0.85)
        .blendMode(.screen)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}
