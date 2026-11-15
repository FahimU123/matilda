import Foundation
import Testing
@testable import Matilda

struct LipInputTests {
    @Test func segmenterFindsAWordBetweenPauses() throws {
        var segmenter = MouthSegmenter()
        var found: MouthedWord?
        for step in 0..<120 {
            let time = Double(step) / 60
            let moving = time >= 0.5 && time < 0.9
            found = segmenter.feed(moving ? [0.4, 0.3, 0.2] : [0, 0, 0], at: time) ?? found
        }
        let word = try #require(found)
        #expect(abs(word.start - 0.5) < 0.02)
        #expect(abs(word.end - 0.883) < 0.02)
    }

    @Test func aTwitchIsNotAWord() {
        var segmenter = MouthSegmenter()
        var found: MouthedWord?
        for step in 0..<60 {
            let time = Double(step) / 60
            found = segmenter.feed(step == 10 ? [0.5, 0.5, 0.5] : [0, 0, 0], at: time) ?? found
        }
        #expect(found == nil)
    }

    @Test func clipCoversTheWordWithPaddingAndMeasuresFrameRate() throws {
        var buffer = FrameBuffer()
        for step in 0..<90 {
            buffer.append(Data([UInt8(step)]), at: Double(step) / 30)
        }
        let clip = try #require(buffer.clip(for: MouthedWord(start: 1.0, end: 1.5)))
        #expect(clip.frames.count == 28)
        #expect(abs(clip.fps - 30) < 0.5)
    }

    @Test(arguments: LipCommand.allCases)
    func serverCommandsMapToAnswers(command: LipCommand) {
        #expect(LipCommand(rawValue: command.rawValue) == command)
    }
}
