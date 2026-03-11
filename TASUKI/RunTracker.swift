//
//  RunTracker.swift
//  TASUKI
//
//  レース中の走行距離を GPS で計測
//

import Foundation
import CoreLocation
import Combine

final class RunTracker: NSObject, ObservableObject {
    static let shared = RunTracker()
    
    @Published var distanceKm: Double = 0
    @Published var isTracking: Bool = false
    @Published var locationError: String?
    
    private let locationManager = CLLocationManager()
    private var lastLocation: CLLocation?
    
    override private init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10
        locationManager.allowsBackgroundLocationUpdates = false
    }
    
    func requestPermissionIfNeeded() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        default:
            break
        }
    }
    
    func start() {
        requestPermissionIfNeeded()
        lastLocation = nil
        distanceKm = 0
        locationError = nil
        locationManager.startUpdatingLocation()
        isTracking = true
    }
    
    func stop() {
        locationManager.stopUpdatingLocation()
        isTracking = false
    }
    
    func reset() {
        lastLocation = nil
        distanceKm = 0
    }
}

extension RunTracker: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last, newLocation.horizontalAccuracy >= 0 else { return }
        if let last = lastLocation {
            let meters = last.distance(from: newLocation)
            if meters > 0 && meters < 500 {
                DispatchQueue.main.async {
                    self.distanceKm += meters / 1000.0
                }
            }
        }
        lastLocation = newLocation
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.locationError = error.localizedDescription
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.locationError = "位置情報が許可されていません"
            }
        default:
            break
        }
    }
}
