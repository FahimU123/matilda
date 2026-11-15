import Foundation

nonisolated struct LiveMatildaAPI: MatildaAPI {
    let baseURL: URL
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

    private func send<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        var request = request
        request.timeoutInterval = 10
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let message = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error ?? "The server returned \(status)."
            throw MatildaAPIError.server(status: status, message: message)
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }

    private struct StartCallResponse: Decodable {
        let callId: String
    }

    private struct ErrorBody: Decodable {
        let error: String
    }
}
