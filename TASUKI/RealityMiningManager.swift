import Foundation
import FirebaseAuth
import FirebaseFirestore

final class RealityMiningManager {
    static let shared = RealityMiningManager()

    private let db = Firestore.firestore()
    private let queue = DispatchQueue(label: "reality.mining.manager")
    private let consentKey = "realityMiningConsentEnabled"

    private init() {}

    var isConsentEnabled: Bool {
        UserDefaults.standard.bool(forKey: consentKey)
    }

    func updateConsent(enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: consentKey)
        trackEvent(
            name: "reality_mining_consent_updated",
            properties: ["enabled": enabled],
            force: true
        )
    }

    func trackScreenView(name: String, properties: [String: Any] = [:]) {
        var merged = properties
        merged["screen_name"] = name
        trackEvent(name: "screen_view", properties: merged)
    }

    func trackEvent(name: String, properties: [String: Any] = [:], force: Bool = false) {
        queue.async {
            guard force || self.isConsentEnabled else { return }
            guard let uid = Auth.auth().currentUser?.uid else { return }

            var payload = properties
            payload["event_name"] = name
            payload["timestamp"] = Timestamp(date: Date())
            payload["client_tz"] = TimeZone.current.identifier
            payload["platform"] = "iOS"
            payload["app_version"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
            payload["build_number"] = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"

            self.db
                .collection("users")
                .document(uid)
                .collection("reality_events")
                .addDocument(data: payload) { error in
                    if let error = error {
                        print("RealityMining track failed: \(error.localizedDescription)")
                    }
                }
        }
    }
}
