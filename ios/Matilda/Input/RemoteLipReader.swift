import Foundation

/// Sends a short clip to the open-source lip-reading model behind the Matilda server.
nonisolated struct RemoteLipReader: LipReadingService {
    let baseURL: URL
    let appKey: String
    var session: URLSession = .shared

    func read(_ clip: LipClip) async throws -> LipCommand? {
        var request = URLRequest(url: baseURL.appending(path: "api/lipread"))
        request.httpMethod = "POST"
        request.timeoutInterval = 8
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(appKey, forHTTPHeaderField: "x-app-key")
        request.httpBody = try await Self.encode(clip)

        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try JSONDecoder().decode(Reply.self, from: data).command.flatMap(LipCommand.init(rawValue:))
    }

    /// Base64 and JSON for a clip is real work, so it runs off the main actor.
    @concurrent private static func encode(_ clip: LipClip) async throws -> Data {
        try JSONEncoder().encode(Body(fps: clip.fps, frames: clip.frames.map { $0.base64EncodedString() }))
    }

    private struct Body: Encodable {
        let fps: Double
        let frames: [String]
    }

    private struct Reply: Decodable {
        let command: String?
    }
}
