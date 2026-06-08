import AVFoundation
import CoreGraphics
import CoreVideo
import Foundation

enum DepthDistanceEstimator {
    static func distanceMeters(from depthData: AVDepthData, faceBounds: CGRect) -> Double? {
        let convertedDepthData = depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
        let depthMap = convertedDepthData.depthDataMap

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)

        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else {
            return nil
        }

        let depthPointer = baseAddress.assumingMemoryBound(to: Float32.self)
        let faceRect = pixelRect(fromVisionBounds: faceBounds, imageWidth: width, imageHeight: height)
        let sampleWidth = Int(faceRect.width)
        let sampleHeight = Int(faceRect.height)
        let stepX = max(1, sampleWidth / 24)
        let stepY = max(1, sampleHeight / 24)
        let minX = max(0, min(width - 1, Int(faceRect.minX.rounded(.down))))
        let maxX = max(minX + 1, min(width, Int(faceRect.maxX.rounded(.up))))
        let minY = max(0, min(height - 1, Int(faceRect.minY.rounded(.down))))
        let maxY = max(minY + 1, min(height, Int(faceRect.maxY.rounded(.up))))
        let floatsPerRow = bytesPerRow / MemoryLayout<Float32>.stride

        var samples: [Double] = []
        samples.reserveCapacity(128)

        var y = minY
        while y < maxY {
            let row = depthPointer + (y * floatsPerRow)

            var x = minX
            while x < maxX {
                let depth = Double(row[x])

                if depth.isFinite, depth >= 0.25, depth <= 5.0 {
                    samples.append(depth)
                }

                x += stepX
            }

            y += stepY
        }

        guard !samples.isEmpty else {
            return nil
        }

        samples.sort()
        return samples[samples.count / 2]
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
}
