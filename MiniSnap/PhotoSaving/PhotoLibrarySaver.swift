import Photos
import UIKit

enum PhotoLibrarySaver {
    nonisolated static func save(_ image: UIImage) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)

        guard status == .authorized || status == .limited else {
            throw PhotoSaveError.notAuthorized
        }

        guard let data = encodedPhotoData(for: image) else {
            throw PhotoSaveError.encodingFailed
        }

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        try data.write(to: fileURL, options: .atomic)

        defer { try? FileManager.default.removeItem(at: fileURL) }

        try await PHPhotoLibrary.shared().performChanges {
            let options = PHAssetResourceCreationOptions()
            options.uniformTypeIdentifier = "public.jpeg"
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, fileURL: fileURL, options: options)
        }
    }

    /// 导出编码：JPEG 比 PNG 编码更快、体积更小，可缩短保存耗时
    nonisolated static func encodedPhotoData(for image: UIImage) -> Data? {
        image.jpegData(compressionQuality: 0.95)
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
