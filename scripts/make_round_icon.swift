import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 3 else {
    fputs("usage: make_round_icon.swift <input.png> <output.png>\n", stderr)
    exit(1)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2]) as CFURL

guard
    let source = CGImageSourceCreateWithURL(inputURL, nil),
    let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
    let context = CGContext(
        data: nil,
        width: 512,
        height: 512,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
else {
    fputs("unable to read input image or create canvas\n", stderr)
    exit(1)
}

context.clear(CGRect(x: 0, y: 0, width: 512, height: 512))
context.addEllipse(in: CGRect(x: 10, y: 10, width: 492, height: 492))
context.clip()
context.draw(image, in: CGRect(x: 0, y: 0, width: 512, height: 512))

guard
    let result = context.makeImage(),
    let destination = CGImageDestinationCreateWithURL(
        outputURL,
        UTType.png.identifier as CFString,
        1,
        nil
    )
else {
    fputs("unable to create output image\n", stderr)
    exit(1)
}

CGImageDestinationAddImage(destination, result, nil)
guard CGImageDestinationFinalize(destination) else {
    fputs("unable to write output image\n", stderr)
    exit(1)
}
