import Foundation
import HealthKit

/// HealthKit との連携を担当するマネージャ
final class HealthKitManager {
    
    static let shared = HealthKitManager()
    
    private let healthStore = HKHealthStore()
    
    private init() {}
    
    /// HealthKit からウォーキング＋ランニング距離を読み取るための権限をリクエストする
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        // 端末が HealthKit をサポートしていない場合
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, NSError(domain: "HealthKit", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "HealthKit is not available on this device."
            ]))
            return
        }
        
        guard let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) else {
            completion(false, NSError(domain: "HealthKit", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "distanceWalkingRunning type is not available."
            ]))
            return
        }
        
        let readTypes: Set<HKObjectType> = [distanceType]
        
        healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }
    
    /// 当月のウォーキング＋ランニング距離 (km) を取得する
    func fetchRunningDistanceThisMonth(completion: @escaping (Result<Double, Error>) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            let error = NSError(domain: "HealthKit", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "HealthKit is not available on this device."
            ])
            completion(.failure(error))
            return
        }
        
        guard let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) else {
            let error = NSError(domain: "HealthKit", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "distanceWalkingRunning type is not available."
            ])
            completion(.failure(error))
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            let error = NSError(domain: "HealthKit", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Failed to calculate start of month."
            ])
            completion(.failure(error))
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfMonth, end: now, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: distanceType,
                                      quantitySamplePredicate: predicate,
                                      options: .cumulativeSum) { _, result, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let sumQuantity = result?.sumQuantity() else {
                // データがない場合は 0km とする
                DispatchQueue.main.async {
                    completion(.success(0.0))
                }
                return
            }
            
            let meters = sumQuantity.doubleValue(for: HKUnit.meter())
            let kilometers = meters / 1000.0
            
            DispatchQueue.main.async {
                completion(.success(kilometers))
            }
        }
        
        healthStore.execute(query)
    }
}

