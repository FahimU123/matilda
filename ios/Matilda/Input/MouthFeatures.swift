import ARKit

nonisolated enum MouthFeatures {
    static let locations: [ARFaceAnchor.BlendShapeLocation] = [
        .jawOpen, .mouthClose, .mouthFunnel, .mouthPucker,
        .mouthSmileLeft, .mouthSmileRight, .mouthStretchLeft, .mouthStretchRight,
        .mouthRollLower, .mouthRollUpper, .mouthLowerDownLeft, .mouthLowerDownRight,
        .mouthUpperUpLeft, .mouthUpperUpRight, .mouthPressLeft, .mouthPressRight,
    ]

    static func vector(from anchor: ARFaceAnchor) -> [Float] {
        locations.map { anchor.blendShapes[$0]?.floatValue ?? 0 }
    }
}
