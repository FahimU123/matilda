import Foundation
import Testing
@testable import Matilda

struct HeadGestureClassifierTests {
    func run(pitch: (Double) -> Double, yaw: (Double) -> Double) -> HeadGesture? {
        var classifier = HeadGestureClassifier()
        var result: HeadGesture?
        for step in 0..<40 {
            let time = Double(step) * 0.025
            result = classifier.feed(HeadSample(time: time, pitch: pitch(time), yaw: yaw(time))) ?? result
        }
        return result
    }

    @Test func smallNodIsDetected() {
        let gesture = run(pitch: { 0.12 * sin($0 * 2 * .pi * 2) }, yaw: { _ in 0.01 })
        #expect(gesture == .nod)
    }

    @Test func headShakeIsDetected() {
        let gesture = run(pitch: { _ in 0.0 }, yaw: { 0.15 * sin($0 * 2 * .pi * 2) })
        #expect(gesture == .shake)
    }

    @Test func aShakeRightAfterANodStillStops() {
        var classifier = HeadGestureClassifier()
        var gestures: [HeadGesture] = []
        for step in 0..<60 {
            let time = Double(step) * 0.025
            let nodding = time < 0.75
            let sample = HeadSample(
                time: time,
                pitch: nodding ? 0.12 * sin(time * 2 * .pi * 2) : 0,
                yaw: nodding ? 0.01 : 0.15 * sin(time * 2 * .pi * 2)
            )
            if let gesture = classifier.feed(sample) { gestures.append(gesture) }
        }
        #expect(gestures.first == .nod)
        #expect(gestures.contains(.shake))
    }

    @Test func slowLookAroundIsIgnored() {
        let gesture = run(pitch: { $0 * 0.05 }, yaw: { $0 * 0.08 })
        #expect(gesture == nil)
    }
}
