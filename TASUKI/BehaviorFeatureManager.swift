import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

struct BehaviorFeatureSnapshot {
    let dateKey: String
    let weeklyRunCount: Int
    let weeklyRunTrendDelta: Int
    let socialActivityScore: Double
    let consistencyScore: Double
    let weekendActivityRatio: Double
    let routineSpreadScore: Double
    let behaviorShiftScore: Double
    let medianMessageIntervalSec: Double?
    let topActiveHour: Int?
}

final class BehaviorFeatureManager: ObservableObject {
    @Published var latestFeature: BehaviorFeatureSnapshot?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private lazy var db: Firestore = {
        FirebaseBootstrap.configureIfNeeded()
        return Firestore.firestore()
    }()

    func fetchLatestFeature() {
        guard let uid = Auth.auth().currentUser?.uid else {
            latestFeature = nil
            return
        }

        isLoading = true
        errorMessage = nil

        db.collection("users")
            .document(uid)
            .collection("behavior_features")
            .order(by: "generatedAt", descending: true)
            .limit(to: 1)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.isLoading = false

                    if let error = error {
                        self.errorMessage = error.localizedDescription
                        RealityMiningManager.shared.trackEvent(
                            name: "behavior_feature_fetch_failed",
                            properties: ["error_message": error.localizedDescription]
                        )
                        return
                    }

                    guard let doc = snapshot?.documents.first else {
                        self.latestFeature = nil
                        RealityMiningManager.shared.trackEvent(name: "behavior_feature_empty")
                        return
                    }

                    let data = doc.data()
                    let feature = BehaviorFeatureSnapshot(
                        dateKey: doc.documentID,
                        weeklyRunCount: data["weeklyRunCount"] as? Int ?? 0,
                        weeklyRunTrendDelta: data["weeklyRunTrendDelta"] as? Int ?? 0,
                        socialActivityScore: data["socialActivityScore"] as? Double ?? 0,
                        consistencyScore: data["consistencyScore"] as? Double ?? 0,
                        weekendActivityRatio: data["weekendActivityRatio"] as? Double ?? 0,
                        routineSpreadScore: data["routineSpreadScore"] as? Double ?? 0,
                        behaviorShiftScore: data["behaviorShiftScore"] as? Double ?? 0,
                        medianMessageIntervalSec: data["medianMessageIntervalSec"] as? Double,
                        topActiveHour: data["topActiveHour"] as? Int
                    )
                    self.latestFeature = feature
                    RealityMiningManager.shared.trackEvent(
                        name: "behavior_feature_fetched",
                        properties: ["date_key": feature.dateKey]
                    )
                }
            }
    }
}
