import Testing
@testable import Matilda

struct CallViewModelTests {
    let channel = SpyChannel()
    let recorder = FakeRecorder()

    func makeCall(vault: StubVault = StubVault(), delay: Duration = .zero) -> CallViewModel {
        CallViewModel(
            callID: "call-1",
            placeName: "Nest Street Pharmacy",
            purpose: "Refill carbidopa-levodopa",
            channel: channel,
            events: AsyncStream { _ in },
            gestures: AsyncStream { _ in },
            vault: vault,
            recorder: recorder,
            reader: StubReader(),
            commitDelay: delay
        )
    }

    @Test func thumbsUpSaysTheHighlightedAnswer() async {
        let call = makeCall()
        call.handle(.cardOpened(callID: "call-1", card: Sample.dobCard))
        call.handle(.confirm(.thumbs))
        await call.commitTask?.value

        #expect(channel.sent == [.answer(cardID: "card-1", suggestionID: "0", method: .thumbs, value: nil)])
    }

    @Test func mouthingANumberChoosesThatAnswer() async {
        let call = makeCall()
        call.handle(.cardOpened(callID: "call-1", card: Sample.choiceCard))
        call.handle(.choose(index: 1, method: .lips))
        await call.commitTask?.value

        #expect(call.highlighted == 1)
        #expect(channel.sent == [.answer(cardID: "card-2", suggestionID: "1", method: .lips, value: nil)])
    }

    @Test func shakingDuringTheSendWindowStopsIt() async {
        let call = makeCall(delay: .seconds(5))
        call.handle(.cardOpened(callID: "call-1", card: Sample.dobCard))
        call.handle(.confirm(.nod))
        call.handle(.decline(.nod))
        await call.commitTask?.value

        #expect(call.pending == nil)
        #expect(channel.sent.isEmpty)
    }

    @Test func shakingWithNothingPendingTellsThemItIsNotRight() async throws {
        let call = makeCall()
        call.handle(.cardOpened(callID: "call-1", card: Sample.dobCard))
        call.handle(.decline(.nod))
        try await Task.sleep(for: .milliseconds(50))

        #expect(channel.sent == [.decline(cardID: "card-1", method: .nod)])
    }

    @Test func mouthingASentenceSaysWhatRayApproves() async {
        let call = makeCall()
        call.handle(.cardOpened(callID: "call-1", card: Sample.choiceCard))
        call.startComposing()
        #expect(recorder.isRecording)

        await call.finishComposing()
        #expect(call.compose == .ready(heard: "i need my carbon dopa"))
        #expect(call.draft == "I need a refill of my carbidopa-levodopa.")

        call.handle(.confirm(.nod))
        await call.commitTask?.value
        #expect(channel.sent == [
            .composing(cardID: "card-2"),
            .say(cardID: "card-2", text: "I need a refill of my carbidopa-levodopa.", method: .nod),
        ])
    }

    @Test func gesturesWhileMouthingAreIgnored() async {
        let call = makeCall()
        call.handle(.cardOpened(callID: "call-1", card: Sample.choiceCard))
        call.startComposing()
        call.handle(.confirm(.lips))
        call.handle(.choose(index: 1, method: .lips))

        #expect(call.pending == nil)
        #expect(call.compose == .recording)
    }

    @Test func aFixedSentenceIsWhatGetsSaid() async {
        let call = makeCall()
        call.handle(.cardOpened(callID: "call-1", card: Sample.choiceCard))
        call.typeInstead()
        call.draft = "  Can you deliver it on Friday?  "
        call.sayDraft(method: .tap)
        await call.commitTask?.value

        #expect(channel.sent == [.say(cardID: "card-2", text: "Can you deliver it on Friday?", method: .tap)])
    }

    @Test func privateNumbersCannotBeMouthed() {
        let call = makeCall()
        call.handle(.cardOpened(callID: "call-1", card: Sample.ssnCard))
        #expect(!call.canCompose)
        call.startComposing()
        #expect(call.compose == .idle)
    }

    @Test func aNewQuestionDropsAHalfFinishedAnswer() {
        let call = makeCall()
        call.handle(.cardOpened(callID: "call-1", card: Sample.choiceCard))
        call.startComposing()
        call.handle(.cardOpened(callID: "call-1", card: Sample.dobCard))

        #expect(call.compose == .idle)
        #expect(!recorder.isRecording)
    }

    @Test func stoppingDuringFaceIDNeverSendsThePrivateNumber() async throws {
        let call = CallViewModel(
            callID: "call-1",
            placeName: "Nest Street Pharmacy",
            purpose: "Refill",
            channel: channel,
            events: AsyncStream { _ in },
            gestures: AsyncStream { _ in },
            vault: SlowVault(),
            recorder: recorder,
            reader: StubReader(),
            commitDelay: .zero
        )
        call.handle(.cardOpened(callID: "call-1", card: Sample.ssnCard))
        call.handle(.confirm(.thumbs))
        try await Task.sleep(for: .milliseconds(30))
        call.handle(.decline(.nod))
        await call.commitTask?.value

        #expect(channel.sent.isEmpty)
    }

    @Test func privateNumbersAreReadFromTheVault() async {
        let call = makeCall(vault: StubVault(value: "6789"))
        call.handle(.cardOpened(callID: "call-1", card: Sample.ssnCard))
        call.handle(.confirm(.tap))
        await call.commitTask?.value

        #expect(channel.sent == [.answer(cardID: "card-3", suggestionID: "0", method: .tap, value: "6789")])
    }

    @Test func failedFaceIDSaysNothing() async {
        let call = makeCall(vault: StubVault(value: nil))
        call.handle(.cardOpened(callID: "call-1", card: Sample.ssnCard))
        call.handle(.confirm(.thumbs))
        await call.commitTask?.value

        #expect(channel.sent.isEmpty)
        #expect(call.notice == VaultError.notAuthenticated.errorDescription)
    }

    @Test func eventsForOtherCallsAreIgnored() {
        let call = makeCall()
        call.handle(.cardOpened(callID: "someone-else", card: Sample.dobCard))
        #expect(call.card == nil)
    }

    @Test func closingTheCardRecordsWhatWasSaid() {
        let call = makeCall()
        call.handle(.cardOpened(callID: "call-1", card: Sample.dobCard))
        call.handle(.cardClosed(callID: "call-1", cardID: "card-1", said: "His date of birth is March 4, 1952."))

        #expect(call.card == nil)
        #expect(call.pending == nil)
    }
}
