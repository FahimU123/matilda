import CoreMotion
import Foundation
import os

nonisolated final class HeadMotionMonitor: NSObject, CMHeadphoneMotionManagerDelegate, @unchecked Sendable {
    private let manager = CMHeadphoneMotionManager()
    private let queue = OperationQueue()
    private let classifier = OSAllocatedUnfairLock(initialState: HeadGestureClassifier())
    private let onGesture: @Sendable (HeadGesture) -> Void
    private let onConnection: @Sendable (Bool) -> Void

    init(onGesture: @escaping @Sendable (HeadGesture) -> Void, onConnection: @escaping @Sendable (Bool) -> Void) {
        self.onGesture = onGesture
        self.onConnection = onConnection
        super.init()
        queue.maxConcurrentOperationCount = 1
        manager.delegate = self
    }

    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    func start() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let sample = HeadSample(time: motion.timestamp, pitch: motion.attitude.pitch, yaw: motion.attitude.yaw)
            if let gesture = classifier.withLock({ $0.feed(sample) }) {
                onGesture(gesture)
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }

    func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        onConnection(true)
    }

    func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
        onConnection(false)
    }
}
