import Foundation
import Observation

/// Owns every hands-free input and merges them into one stream of answers for the call screen.
@Observable
final class GestureHub: LipRecorder {
    private(set) var cameraRunning = false
    private(set) var airPodsConnected = false
    private(set) var readingLips = false
    private(set) var lastSignal: String?
    private(set) var lastSource: InputSource?
    private(set) var signals = 0
    /// Live camera feedback while Ray mouths a longer answer; nil when not recording.
    private(set) var recording: RecordingStatus?

    @ObservationIgnored private var continuation: AsyncStream<GestureEvent>.Continuation?
    @ObservationIgnored private var camera: FaceCamera?
    @ObservationIgnored private var headMotion: HeadMotionMonitor?
    @ObservationIgnored private let lipReader: (any LipReadingService)?
    @ObservationIgnored private var question: String?
    @ObservationIgnored private var questionOpenedAt = Date.distantPast
    @ObservationIgnored private var lipRead: Task<Void, Never>?
    @ObservationIgnored private var onRecordingFinished: (() -> Void)?
    /// Ignores gestures that began before the question appeared, like a listening nod.
    @ObservationIgnored private let settleTime: TimeInterval = 0.5

    init(lipReader: (any LipReadingService)? = nil) {
        self.lipReader = lipReader
    }

    var cameraSupported: Bool { FaceCamera.isSupported }

    func events() -> AsyncStream<GestureEvent> {
        continuation?.finish()
        let (stream, continuation) = AsyncStream.makeStream(of: GestureEvent.self, bufferingPolicy: .bufferingNewest(4))
        self.continuation = continuation
        return stream
    }

    func start() {
        guard camera == nil else { return }
        let camera = FaceCamera(handlers: .init(
            thumb: { [weak self] pose in Task { @MainActor in self?.handle(pose) } },
            mouthed: { [weak self] clip in Task { @MainActor in self?.handle(clip) } },
            recording: { [weak self] status in Task { @MainActor in self?.updateRecording(status) } },
            recordingFinished: { [weak self] in Task { @MainActor in self?.recordingDidFinish() } }
        ))
        let headMotion = HeadMotionMonitor(
            onGesture: { [weak self] gesture in Task { @MainActor in self?.handle(gesture) } },
            onConnection: { [weak self] connected in Task { @MainActor in self?.airPodsConnected = connected } }
        )
        camera.start()
        headMotion.start()
        if question != nil { camera.setCapturing(true) }
        self.camera = camera
        self.headMotion = headMotion
        cameraRunning = FaceCamera.isSupported
    }

    /// Answers are only taken while a question is on screen. The token ties a lip read to its question.
    func beginAnswering(_ token: String) {
        guard question != token else { return }
        question = token
        questionOpenedAt = .now
        lipRead?.cancel()
        camera?.setCapturing(true)
    }

    func endAnswering() {
        question = nil
        lipRead?.cancel()
        camera?.setCapturing(false)
    }

    func startRecording(onFinished: @escaping () -> Void) {
        lipRead?.cancel()
        onRecordingFinished = onFinished
        recording = RecordingStatus(faceVisible: true, lipsMoving: false)
        camera?.startRecording()
    }

    func finishRecording() -> LipClip? {
        onRecordingFinished = nil
        recording = nil
        return camera?.finishRecording()
    }

    func cancelRecording() {
        _ = finishRecording()
    }

    private func updateRecording(_ status: RecordingStatus) {
        guard recording != nil else { return }
        recording = status
    }

    private func recordingDidFinish() {
        let finished = onRecordingFinished
        onRecordingFinished = nil
        finished?()
    }

    func stop() {
        cancelRecording()
        endAnswering()
        camera?.stop()
        headMotion?.stop()
        camera = nil
        headMotion = nil
        cameraRunning = false
        airPodsConnected = false
        lastSource = nil
    }

    private func handle(_ pose: ThumbPose) {
        switch pose {
        case .up: emit(.confirm(.thumbs), signal: "Thumbs up", from: .camera)
        case .down: emit(.decline(.thumbs), signal: "Thumbs down", from: .camera)
        case .none: break
        }
    }

    private func handle(_ gesture: HeadGesture) {
        switch gesture {
        case .nod: emit(.confirm(.nod), signal: "Head nod", from: .airPods)
        case .shake: emit(.decline(.nod), signal: "Head shake", from: .airPods)
        }
    }

    private func handle(_ clip: LipClip) {
        guard let lipReader, let token = question, !readingLips else { return }
        readingLips = true
        lipRead = Task {
            defer { readingLips = false }
            guard let command = try? await lipReader.read(clip), !Task.isCancelled, question == token else { return }
            emit(command.gesture, signal: "Read your lips: \(command.spoken.lowercased())", from: .lips)
        }
    }

    private func emit(_ event: GestureEvent, signal: String, from source: InputSource) {
        guard question != nil, recording == nil, Date.now.timeIntervalSince(questionOpenedAt) >= settleTime else { return }
        lastSignal = signal
        lastSource = source
        signals += 1
        continuation?.yield(event)
    }
}
