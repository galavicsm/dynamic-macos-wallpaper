import Foundation
import ImageIO
import UniformTypeIdentifiers

enum DynamicWallpaperError: Error, CustomStringConvertible {
    case usage
    case missingValue(String)
    case sourceOpenFailed(String)
    case imageDecodeFailed(String)
    case destinationCreateFailed(String)
    case metadataNamespaceFailed
    case metadataWriteFailed
    case finalizeFailed

    var description: String {
        switch self {
        case .usage:
            return """
            Usage: swift make_dynamic.swift --light <light-image> --dark <dark-image> --output <output.heic>

            Parameters:
              --light   Path to the light/day image
              --dark    Path to the dark/night image
              --output  Path to the output HEIC file
            """
        case .missingValue(let flag):
            return "Missing value for \(flag)"
        case .sourceOpenFailed(let path):
            return "Could not open image source: \(path)"
        case .imageDecodeFailed(let path):
            return "Could not decode image: \(path)"
        case .destinationCreateFailed(let path):
            return "Could not create HEIC destination: \(path)"
        case .metadataNamespaceFailed:
            return "Could not register Apple desktop metadata namespace"
        case .metadataWriteFailed:
            return "Could not attach Apple desktop appearance metadata"
        case .finalizeFailed:
            return "Could not finalize HEIC output"
        }
    }
}

struct SourceImage {
    let cgImage: CGImage
    let properties: [CFString: Any]
}

struct CLIArguments {
    let lightPath: String
    let darkPath: String
    let outputPath: String
}

func loadImage(at path: String) throws -> SourceImage {
    let url = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
        throw DynamicWallpaperError.sourceOpenFailed(path)
    }
    guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw DynamicWallpaperError.imageDecodeFailed(path)
    }
    let properties = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]) ?? [:]
    return SourceImage(cgImage: image, properties: properties)
}

func appearanceMetadata() throws -> CGImageMetadata {
    let appearanceMapping: [String: Int] = ["l": 0, "d": 1]
    let plistData = try PropertyListSerialization.data(
        fromPropertyList: appearanceMapping,
        format: .binary,
        options: 0
    )

    let metadata = CGImageMetadataCreateMutable()
    var error: Unmanaged<CFError>?
    let namespace = "http://ns.apple.com/namespace/1.0/" as CFString
    let prefix = "apple_desktop" as CFString

    guard CGImageMetadataRegisterNamespaceForPrefix(metadata, namespace, prefix, &error) else {
        throw DynamicWallpaperError.metadataNamespaceFailed
    }

    let base64Value = plistData.base64EncodedString() as CFString
    let ok = CGImageMetadataSetValueWithPath(
        metadata,
        nil,
        "apple_desktop:apr" as CFString,
        base64Value
    )

    guard ok else {
        throw DynamicWallpaperError.metadataWriteFailed
    }

    return metadata
}

func normalizedProperties(from properties: [CFString: Any]) -> [CFString: Any] {
    var cleaned = properties
    cleaned.removeValue(forKey: kCGImagePropertyPNGDictionary)
    cleaned[kCGImagePropertyOrientation] = 1
    return cleaned
}

func makeDestination(url: URL, imageCount: Int, typeIdentifier: String) throws -> CGImageDestination {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        typeIdentifier as CFString,
        imageCount,
        nil
    ) else {
        throw DynamicWallpaperError.destinationCreateFailed(url.path)
    }
    return destination
}

func buildDynamicWallpaper(lightPath: String, darkPath: String, outputPath: String) throws {
    let light = try loadImage(at: lightPath)
    let dark = try loadImage(at: darkPath)

    let outputURL = URL(fileURLWithPath: outputPath)
    let destination = try makeDestination(url: outputURL, imageCount: 2, typeIdentifier: UTType.heic.identifier)

    let metadata = try appearanceMetadata()

    let frameProperties: [CFString: Any] = [
        kCGImageDestinationLossyCompressionQuality: 0.95
    ]

    var lightProps = normalizedProperties(from: light.properties)
    frameProperties.forEach { lightProps[$0.key] = $0.value }

    var darkProps = normalizedProperties(from: dark.properties)
    frameProperties.forEach { darkProps[$0.key] = $0.value }

    CGImageDestinationAddImageAndMetadata(destination, light.cgImage, metadata, lightProps as CFDictionary)
    CGImageDestinationAddImage(destination, dark.cgImage, darkProps as CFDictionary)

    guard CGImageDestinationFinalize(destination) else {
        throw DynamicWallpaperError.finalizeFailed
    }
}

func parseArguments(_ args: [String]) throws -> CLIArguments {
    var lightPath: String?
    var darkPath: String?
    var outputPath: String?

    var index = 1
    while index < args.count {
        let flag = args[index]
        guard index + 1 < args.count else {
            throw DynamicWallpaperError.missingValue(flag)
        }

        let value = args[index + 1]
        switch flag {
        case "--light":
            lightPath = value
        case "--dark":
            darkPath = value
        case "--output":
            outputPath = value
        default:
            throw DynamicWallpaperError.usage
        }

        index += 2
    }

    guard let lightPath, let darkPath, let outputPath else {
        throw DynamicWallpaperError.usage
    }

    return CLIArguments(lightPath: lightPath, darkPath: darkPath, outputPath: outputPath)
}

do {
    let parsed = try parseArguments(CommandLine.arguments)

    try buildDynamicWallpaper(
        lightPath: parsed.lightPath,
        darkPath: parsed.darkPath,
        outputPath: parsed.outputPath
    )
    print("Created dynamic wallpaper at \(parsed.outputPath)")
} catch {
    fputs("\(error)\n", stderr)
    exit(1)
}
