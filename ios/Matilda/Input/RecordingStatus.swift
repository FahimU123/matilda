/// What the camera sees while Ray mouths a longer answer, so the screen can tell him it is working.
nonisolated struct RecordingStatus: Equatable, Sendable {
    var faceVisible: Bool
    var lipsMoving: Bool
}
