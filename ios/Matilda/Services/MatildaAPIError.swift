import Foundation

nonisolated enum MatildaAPIError: LocalizedError, Equatable {
    case server(status: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .server(_, let message): message
        }
    }
}
