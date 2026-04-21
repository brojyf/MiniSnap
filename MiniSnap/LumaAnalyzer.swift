import CoreGraphics
import CoreVideo
import Foundation

struct SceneMeasurement: Equatable {
    let input: ExposureInput
    let faceBounds: CGRect
}

struct LumaStats: Equatable {
    let average: Double
    let highlightRatio: Double
}

enum LumaAnalyzer {
    static func measurement(pixelBuffer: CVPixelBuffer, faceBounds: CGRect, distance: Double) -> SceneMeasurement? {
        guard CVPixelBufferIsPlanar(pixelBuffer) else {
            return nil
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)

        guard let baseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else {
            return nil
        }

        let lumaPointer = baseAddress.assumingMemoryBound(to: UInt8.self)
        let sceneStats = stats(
            lumaPointer: lumaPointer,
            width: width,
            height: height,
            bytesPerRow: bytesPerRow,
            rect: CGRect(x: 0, y: 0, width: width, height: height)
        )

        let faceRect = pixelRect(fromVisionBounds: faceBounds, imageWidth: width, imageHeight: height)
        let faceStats = stats(
            lumaPointer: lumaPointer,
            width: width,
            height: height,
            bytesPerRow: bytesPerRow,
            rect: faceRect
        )

        guard faceStats.average > 0 else {
            return nil
        }

        let faceAreaRatio = (faceRect.width * faceRect.height) / Double(width * height)
        let input = ExposureInput(
            faceLuma: faceStats.average,
            sceneLuma: sceneStats.average,
            highlightRatio: sceneStats.highlightRatio,
            faceAreaRatio: faceAreaRatio,
            distance: distance
        )

        return SceneMeasurement(input: input, faceBounds: faceBounds)
    }

    private static func pixelRect(fromVisionBounds bounds: CGRect, imageWidth: Int, imageHeight: Int) -> CGRect {
        let x = bounds.minX * Double(imageWidth)
        let y = (1 - bounds.maxY) * Double(imageHeight)
        let width = bounds.width * Double(imageWidth)
        let height = bounds.height * Double(imageHeight)

        return CGRect(
            x: max(0, min(Double(imageWidth - 1), x)),
            y: max(0, min(Double(imageHeight - 1), y)),
            width: max(1, min(Double(imageWidth), width)),
            height: max(1, min(Double(imageHeight), height))
        )
    }

    private static func stats(
        lumaPointer: UnsafePointer<UInt8>,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        rect: CGRect
    ) -> LumaStats {
        let minX = max(0, min(width - 1, Int(rect.minX.rounded(.down))))
        let maxX = max(minX + 1, min(width, Int(rect.maxX.rounded(.up))))
        let minY = max(0, min(height - 1, Int(rect.minY.rounded(.down))))
        let maxY = max(minY + 1, min(height, Int(rect.maxY.rounded(.up))))
        let sampleWidth = maxX - minX
        let sampleHeight = maxY - minY
        let stepX = max(1, sampleWidth / 96)
        let stepY = max(1, sampleHeight / 128)

        var total = 0.0
        var count = 0.0
        var highlights = 0.0

        var y = minY
        while y < maxY {
            let row = lumaPointer + (y * bytesPerRow)

            var x = minX
            while x < maxX {
                let luma = Double(row[x]) / 255.0
                total += luma
                count += 1

                if luma > 0.9 {
                    highlights += 1
                }

                x += stepX
            }

            y += stepY
        }

        guard count > 0 else {
            return LumaStats(average: 0, highlightRatio: 0)
        }

        return LumaStats(average: total / count, highlightRatio: highlights / count)
    }
}
