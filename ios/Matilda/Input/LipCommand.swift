nonisolated enum LipCommand: String, CaseIterable, Sendable {
    case yes, no, one, two, three

    var spoken: String {
        switch self {
        case .yes: "Yes"
        case .no: "No"
        case .one: "One"
        case .two: "Two"
        case .three: "Three"
        }
    }

    var gesture: GestureEvent {
        switch self {
        case .yes: .confirm(.lips)
        case .no: .decline(.lips)
        case .one: .choose(index: 0, method: .lips)
        case .two: .choose(index: 1, method: .lips)
        case .three: .choose(index: 2, method: .lips)
        }
    }
}
