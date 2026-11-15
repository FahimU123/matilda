import Observation
import UIKit

@Observable
final class AppModel {
    enum Load: Equatable {
        case loading
        case ready(Profile)
        case failed(String)
    }

    private(set) var load: Load = .loading
    var activeCall: CallViewModel?
    private(set) var startingPlaceID: String?
    var showsStartError = false
    private(set) var startError: String?

    let gestures: GestureHub
    @ObservationIgnored let vault: any SecureVault
    @ObservationIgnored private let api: any MatildaAPI
    @ObservationIgnored private let channel: WebSocketCallChannel
    @ObservationIgnored private let profileID: String
    @ObservationIgnored let store: LocalStore?

    init(
        configuration: AppConfiguration,
        vault: any SecureVault = KeychainVault(),
        gestures: GestureHub? = nil,
        store: LocalStore? = (try? LocalStore()) ?? (try? LocalStore(inMemory: true))
    ) {
        self.store = store
        api = LiveMatildaAPI(baseURL: configuration.serverURL)
        channel = WebSocketCallChannel(serverURL: configuration.serverURL, profileID: configuration.profileID, appKey: configuration.appKey)
        profileID = configuration.profileID
        self.vault = vault
        self.gestures = gestures ?? GestureHub(lipReader: RemoteLipReader(baseURL: configuration.serverURL, appKey: configuration.appKey))
    }

    var profile: Profile? {
        if case .ready(let profile) = load { profile } else { nil }
    }

    func refresh() async {
        channel.start()
        if profile == nil, let cached = store?.cachedProfile(id: profileID) {
            load = .ready(cached)
        }
        do {
            let profile = try await api.profile(id: profileID)
            load = .ready(profile)
            try? store?.cache(profile)
            #if DEBUG
            if activeCall == nil, let placeID = UserDefaults.standard.string(forKey: "autoCall"),
               let place = profile.places.first(where: { $0.id == placeID }) {
                await call(place)
            }
            #endif
        } catch {
            if profile == nil { load = .failed(error.localizedDescription) }
        }
    }

    func call(_ place: Place) async {
        guard startingPlaceID == nil, let profile else { return }
        startingPlaceID = place.id
        defer { startingPlaceID = nil }
        // Subscribe before placing the call so no early event (ringing, first captions) is missed.
        let events = channel.events()
        do {
            let callID = try await api.startCall(profileID: profile.id, placeID: place.id)
            gestures.start()
            let call = CallViewModel(
                callID: callID,
                placeName: place.name,
                purpose: place.purpose,
                channel: channel,
                events: events,
                gestures: gestures.events(),
                vault: vault
            )
            call.start()
            activeCall = call
            // Ray answers without touching the screen, so it must not lock mid-call.
            UIApplication.shared.isIdleTimerDisabled = true
        } catch {
            startError = error.localizedDescription
            showsStartError = true
        }
    }

    private(set) var practiceRequests = 0

    func requestPractice() {
        practiceRequests += 1
    }

    func closeCall() {
        if let call = activeCall, case .ended(let summary) = call.stage {
            try? store?.record(
                callID: call.callID,
                placeName: call.placeName,
                startedAt: call.liveSince ?? .now,
                summary: summary ?? "Call to \(call.placeName)",
                answers: call.consents
            )
        }
        activeCall?.stop()
        activeCall = nil
        gestures.stop()
        UIApplication.shared.isIdleTimerDisabled = false
    }
}
