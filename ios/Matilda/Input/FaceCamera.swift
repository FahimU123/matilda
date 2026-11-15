import ARKit
import CoreImage
import Foundation
import os

/// One front camera session that serves two jobs: TrueDepth face tracking to notice when a word is mouthed,
/// and the same frames passed to Vision for thumbs up and down. Work only happens while a question is open.
/// Frames stay in memory and only a short clip around a mouthed word is sent to the Matilda server to be read.
nonisolated final class FaceCamera: NSObject, ARSessionDelegate, @unchecked Sendable {
    struct Handlers: Sendable {
        var thumb: @Sendable (ThumbPose) -> Void
        var mouthed: @Sendable (LipClip) -> Void
    }

    static var isSupported: Bool { ARFaceTrackingConfiguration.isSupported }

    private let session = ARSession()
    private let queue = DispatchQueue(label: "app.matilda.face-camera")
    private let reader = HandPoseReader()
    private let imageContext = CIContext()
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private let state = OSAllocatedUnfairLock(initialState: State())
    private let handlers: Handlers

    private struct State {
        var thumbs = PoseDebouncer<ThumbPose>(idle: .none)
        var segmenter = MouthSegmenter()
        var frames = FrameBuffer()
        var frameCount = 0
        var capturing = false
    }

    init(handlers: Handlers) {
        self.handlers = handlers
        super.init()
        session.delegate = self
        session.delegateQueue = queue
    }

    func start() {
        guard Self.isSupported else { return }
        let configuration = ARFaceTrackingConfiguration()
        configuration.maximumNumberOfTrackedFaces = 1
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    func stop() {
        session.pause()
    }

    /// Starts or stops listening for answers. Each new question starts from a clean slate,
    /// so a gesture or word from before it appeared can never answer it.
    func setCapturing(_ capturing: Bool) {
        state.withLock { state in
            state.capturing = capturing
            state.thumbs = PoseDebouncer(idle: .none)
            state.segmenter = MouthSegmenter()
            state.frames = FrameBuffer()
        }
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let count: Int? = state.withLock { state in
            guard state.capturing else { return nil }
            state.frameCount += 1
            return state.frameCount
        }
        guard let count else { return }

        if count.isMultiple(of: 2), let jpeg = uprightJPEG(frame.capturedImage) {
            state.withLock { $0.frames.append(jpeg, at: frame.timestamp) }
        }

        if let face = frame.anchors.compactMap({ $0 as? ARFaceAnchor }).first, face.isTracked {
            let features = MouthFeatures.vector(from: face)
            let clip = state.withLock { state in
                state.segmenter.feed(features, at: frame.timestamp).flatMap { state.frames.clip(for: $0) }
            }
            if let clip { handlers.mouthed(clip) }
        }

        guard count.isMultiple(of: 3) else { return }
        let pose = reader.joints(in: frame.capturedImage, orientation: .leftMirrored).map(ThumbClassifier.classify) ?? .none
        if let fired = state.withLock({ $0.thumbs.feed(pose, at: frame.timestamp) }) {
            handlers.thumb(fired)
        }
    }

    private func uprightJPEG(_ buffer: CVPixelBuffer) -> Data? {
        let image = CIImage(cvPixelBuffer: buffer).oriented(.leftMirrored)
        let scale = 480 / max(image.extent.height, 1)
        let small = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return imageContext.jpegRepresentation(
            of: small,
            colorSpace: colorSpace,
            options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.7]
        )
    }
}
