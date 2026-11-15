import Foundation

nonisolated struct LiveMatildaAPI: MatildaAPI, AnswerReader {
    let baseURL: URL
    let appKey: String
    var session: URLSession = .shared

    func profile(id: String) async throws -> Profile {
        try await send(URLRequest(url: baseURL.appending(path: "api/profiles/\(id)")))
    }

    func startCall(profileID: String, placeID: String) async throws -> String {
        var request = URLRequest(url: baseURL.appending(path: "api/calls"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["profileId": profileID, "placeId": placeID])
        let response: StartCallResponse = try await send(request)
        return response.callId
    }

    func readAnswer(cardID: String, clip: LipClip) async throws -> LipReading {
        var request = URLRequest(url: baseURL.appending(path: "api/cards/\(cardID)/read"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(appKey, forHTTPHeaderField: "x-app-key")
        request.httpBody = try await Self.encode(clip)
        return try await send(request, timeout: 25)
    }

    /// A sentence clip is a few megabytes of base64, so it is built off the main actor.
    @concurrent private static func encode(_ clip: LipClip) async throws -> Data {
        try JSONEncoder().encode(ClipBody(fps: clip.fps, frames: clip.frames.map { $0.base64EncodedString() }))
    }

    private func send<Response: Decodable>(_ request: URLRequest, timeout: TimeInterval = 10) async throws -> Response {
        var request = request
        request.timeoutInterval = timeout
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let message = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error ?? "The server returned \(status)."
            throw MatildaAPIError.server(status: status, message: message)
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }

    private struct ClipBody: Encodable {
        let fps: Double
        let frames: [String]
    }

    private struct StartCallResponse: Decodable {
        let callId: String
    }

    private struct ErrorBody: Decodable {
        let error: String
    }
}
