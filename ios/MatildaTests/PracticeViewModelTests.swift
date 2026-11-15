import Testing
@testable import Matilda

struct PracticeViewModelTests {
    let practice = PracticeViewModel(gestures: AsyncStream { _ in })

    @Test(arguments: [GestureEvent.confirm(.nod), .confirm(.thumbs), .choose(index: 0, method: .lips)])
    func anyApprovalCountsAsSayingIt(gesture: GestureEvent) {
        practice.handle(gesture)
        #expect(practice.result != .waiting)
        #expect(practice.result != .stopped)
    }

    @Test func aHeadShakeStops() {
        practice.handle(.decline(.nod))
        #expect(practice.result == .stopped)
    }

    @Test func tryingAgainResets() {
        practice.tap()
        practice.reset()
        #expect(practice.result == .waiting)
    }
}
