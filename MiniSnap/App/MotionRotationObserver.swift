import Combine
import CoreMotion
import SwiftUI

final class MotionRotationObserver: ObservableObject {
    @Published private(set) var rotationAngle: Angle = .zero

    private let motionManager = CMMotionManager()

    func start() {
        guard motionManager.isDeviceMotionAvailable else {
            return
        }

        motionManager.deviceMotionUpdateInterval = 0.2
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let gravity = motion?.gravity else {
                return
            }

            self?.rotationAngle = Self.angle(forGravityX: gravity.x, y: gravity.y)
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
    }

    private static func angle(forGravityX x: Double, y: Double) -> Angle {
        if abs(x) > abs(y) {
            return .degrees(x > 0 ? -90 : 90)
        }

        return .degrees(y > 0 ? 180 : 0)
    }
}
