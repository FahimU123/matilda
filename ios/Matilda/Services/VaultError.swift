import Foundation

nonisolated enum VaultError: LocalizedError, Equatable {
    case missing
    case keychain(OSStatus)
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .missing: "That number is not saved on this phone yet."
        case .keychain(let status): "The keychain refused the request (\(status))."
        case .notAuthenticated: "Face ID did not confirm it was you, so nothing was said."
        }
    }
}
