import Combine
import CoreGraphics
import Foundation
import ImageIO
import WatchConnectivity

final class WatchPreviewReceiver: NSObject, ObservableObject {
    @Published private(set) var previewImage: CGImage?
    @Published private(set) var statusText = "等待 iPhone 预览"

    private let session: WCSession?

    override init() {
        if WCSession.isSupported() {
            let session = WCSession.default
            self.session = session
            super.init()
            session.delegate = self
            session.activate()
        } else {
            session = nil
            super.init()
            statusText = "当前手表不支持连接"
        }
    }
}

extension WatchPreviewReceiver: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            if let error {
                self?.statusText = "连接失败：\(error.localizedDescription)"
            } else {
                self?.statusText = activationState == .activated ? "等待 iPhone 预览" : "连接未激活"
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        guard
            let source = CGImageSourceCreateWithData(messageData as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            Task { @MainActor [weak self] in
                self?.statusText = "预览解码失败"
            }
            return
        }

        Task { @MainActor [weak self] in
            self?.previewImage = image
            self?.statusText = "实时预览"
        }
    }
}
