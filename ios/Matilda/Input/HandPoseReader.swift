import CoreVideo
import ImageIO
import Vision

nonisolated struct HandPoseReader: Sendable {
    func joints(in pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) -> HandJoints? {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 1
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation)
        guard (try? handler.perform([request])) != nil,
              let observation = request.results?.first,
              let points = try? observation.recognizedPoints(.all)
        else { return nil }

        func point(_ name: VNHumanHandPoseObservation.JointName) -> HandPoint? {
            guard let recognized = points[name], recognized.confidence > 0.3 else { return nil }
            return HandPoint(x: recognized.location.x, y: recognized.location.y)
        }

        guard let wrist = point(.wrist), let tip = point(.thumbTip), let ip = point(.thumbIP), let mp = point(.thumbMP)
        else { return nil }

        let fingers: [(VNHumanHandPoseObservation.JointName, VNHumanHandPoseObservation.JointName)] = [
            (.indexTip, .indexMCP), (.middleTip, .middleMCP), (.ringTip, .ringMCP), (.littleTip, .littleMCP),
        ]
        let pairs = fingers.compactMap { tipName, knuckleName -> (HandPoint, HandPoint)? in
            guard let tip = point(tipName), let knuckle = point(knuckleName) else { return nil }
            return (tip, knuckle)
        }
        guard pairs.count >= 3 else { return nil }

        return HandJoints(
            wrist: wrist,
            thumbTip: tip,
            thumbIP: ip,
            thumbMP: mp,
            fingerTips: pairs.map(\.0),
            fingerKnuckles: pairs.map(\.1)
        )
    }
}
