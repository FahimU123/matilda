import Foundation

/// Detects a nod (pitch swinging down and back) or a shake (yaw swinging side to side)
/// from AirPods head motion. Thresholds are deliberately forgiving because Parkinson's
/// reduces movement range.
nonisolated struct HeadGestureClassifier: Sendable {
    var window: TimeInterval = 1.4
    var minimumSwing: Double = 0.12
    var cooldown: TimeInterval = 1.5

    private var samples: [HeadSample] = []
    private var lastFired: TimeInterval = -.infinity
    private var lastGesture: HeadGesture?

    mutating func feed(_ sample: HeadSample) -> HeadGesture? {
        samples.append(sample)
        samples.removeAll { sample.time - $0.time > window }
        guard samples.count >= 6 else { return nil }

        let pitch = samples.map(\.pitch)
        let yaw = samples.map(\.yaw)
        let pitchSwing = swing(pitch)
        let yawSwing = swing(yaw)

        let gesture: HeadGesture?
        if pitchSwing >= minimumSwing, pitchSwing > yawSwing * 1.6, reversals(pitch) >= 2 {
            gesture = .nod
        } else if yawSwing >= minimumSwing, yawSwing > pitchSwing * 1.6, reversals(yaw) >= 2 {
            gesture = .shake
        } else {
            gesture = nil
        }

        guard let gesture else { return nil }
        // Only a repeat of the same gesture waits out the cooldown; a shake right after a nod must still stop it.
        if gesture == lastGesture, sample.time - lastFired < cooldown { return nil }
        lastFired = sample.time
        lastGesture = gesture
        samples.removeAll()
        return gesture
    }

    private func swing(_ values: [Double]) -> Double {
        guard let low = values.min(), let high = values.max() else { return 0 }
        return high - low
    }

    private func reversals(_ values: [Double]) -> Int {
        let deadband = minimumSwing / 4
        var count = 0
        var direction = 0
        var anchor = values.first ?? 0
        for value in values.dropFirst() {
            let delta = value - anchor
            guard abs(delta) > deadband else { continue }
            let next = delta > 0 ? 1 : -1
            if direction != 0, next != direction { count += 1 }
            direction = next
            anchor = value
        }
        return count
    }
}
