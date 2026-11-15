/// Records Ray mouthing a whole sentence. `onFinished` fires once when his lips have rested
/// after speaking, or when the time limit is reached.
protocol LipRecorder: AnyObject {
    func startRecording(onFinished: @escaping () -> Void)
    func finishRecording() -> LipClip?
    func cancelRecording()
}
