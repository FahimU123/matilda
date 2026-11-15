import Foundation

nonisolated struct AppConfiguration: Sendable {
    let serverURL: URL
    let profileID: String
    let appKey: String

    static func fromBundle(_ bundle: Bundle = .main) -> AppConfiguration {
        let rawURL = bundle.object(forInfoDictionaryKey: "MatildaServerURL") as? String ?? ""
        let profileID = bundle.object(forInfoDictionaryKey: "MatildaProfileID") as? String ?? "ray"
        let appKey = bundle.object(forInfoDictionaryKey: "MatildaAppKey") as? String ?? ""
        guard let url = URL(string: rawURL), url.scheme != nil else {
            fatalError("MatildaServerURL is missing. Copy Config/Matilda.xcconfig.example to Config/Matilda.xcconfig.")
        }
        return AppConfiguration(serverURL: url, profileID: profileID.isEmpty ? "ray" : profileID, appKey: appKey)
    }
}
