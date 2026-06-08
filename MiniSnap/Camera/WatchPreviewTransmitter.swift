import UIKit
import WatchConnectivity

final class WatchPreviewTransmitter: NSObject {
    private let session: WCSession?
    private var lastSentAt = Date.distantPast
    private let minimumInterval: TimeInterval = 0.5

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
        }
    }

    func sendPreview(image: UIImage?) {
        guard
            let image,
            let session,
            session.activationState == .activated,
            session.isPaired,
            session.isWatchAppInstalled,
            session.isReachable
        else {
            return
        }

        let now = Date()
        guard now.timeIntervalSince(lastSentAt) >= minimumInterval else {
            return
        }

        guard let data = previewData(from: image) else {
            return
        }

        lastSentAt = now
        session.sendMessageData(data, replyHandler: nil) { [weak self] _ in
            self?.lastSentAt = .distantPast
        }
    }

    private func previewData(from image: UIImage) -> Data? {
        let targetSize = CGSize(width: 180, height: 240)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        return resized.jpegData(compressionQuality: 0.55)
    }
}

extension WatchPreviewTransmitter: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
