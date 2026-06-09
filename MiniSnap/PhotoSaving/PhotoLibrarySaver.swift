import Photos
import UIKit

enum PhotoLibrarySaver {
    static func save(_ image: UIImage) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)

        guard status == .authorized || status == .limited else {
            throw PhotoSaveError.notAuthorized
        }

        guard let data = image.pngData() else {
            throw PhotoSaveError.encodingFailed
        }

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")
        try data.write(to: fileURL, options: .atomic)

        defer { try? FileManager.default.removeItem(at: fileURL) }

        try await PHPhotoLibrary.shared().performChanges {
            let options = PHAssetResourceCreationOptions()
            options.uniformTypeIdentifier = "public.png"
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, fileURL: fileURL, options: options)
        }
    }
}

enum PhotoSaveError: LocalizedError {
    case notAuthorized
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "没有相册写入权限"
        case .encodingFailed:
            return "图片编码失败"
        }
    }
}
