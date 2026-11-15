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
        var recording: @Sendable (RecordingStatus) -> Void
        var recordingFinished: @Sendable () -> Void
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
        var sentence: SentenceRecording?
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

    func startRecording() {
        state.withLock { $0.sentence = SentenceRecording() }
    }

    /// Ends the recording and returns the part where the lips moved.
    func finishRecording() -> LipClip? {
        state.withLock { state in
            defer { state.sentence = nil }
            return state.sentence?.clip()
        }
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let count: Int? = state.withLock { state in
            guard state.capturing else { return nil }
            state.frameCount += 1
            return state.frameCount
        }
        guard let count else { return }

        if state.withLock({ $0.sentence != nil }) {
            record(frame, count: count)
            return
        }

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

    /// Sentence clips are long, so frames are smaller to keep the upload to a few megabytes.
    private func record(_ frame: ARFrame, count: Int) {
        let jpeg = count.isMultiple(of: 2) ? uprightJPEG(frame.capturedImage, height: 360, quality: 0.6) : nil
        let face = frame.anchors.lazy.compactMap { $0 as? ARFaceAnchor }.first { $0.isTracked }
        let features = face.map(MouthFeatures.vector(from:))

        let (finished, status) = state.withLock { state -> (Bool, RecordingStatus?) in
            guard state.sentence != nil else { return (false, nil) }
            if let jpeg { state.sentence?.append(jpeg, at: frame.timestamp) }
            let finished = features.map { state.sentence?.feed($0, at: frame.timestamp) ?? false } ?? false
            let moving = features != nil && (state.sentence?.lipsMoving ?? false)
            return (finished, count.isMultiple(of: 6) ? RecordingStatus(faceVisible: face != nil, lipsMoving: moving) : nil)
        }
        if let status { handlers.recording(status) }
        if finished { handlers.recordingFinished() }
    }

    private func uprightJPEG(_ buffer: CVPixelBuffer, height: Double = 480, quality: Double = 0.7) -> Data? {
        let image = CIImage(cvPixelBuffer: buffer).oriented(.leftMirrored)
        let scale = height / max(image.extent.height, 1)
        let small = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return imageContext.jpegRepresentation(
            of: small,
            colorSpace: colorSpace,
            options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: quality]
        )
    }
}
