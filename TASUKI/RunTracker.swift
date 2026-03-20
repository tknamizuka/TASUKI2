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
    @Published var isPaused: Bool = false
    @Published var locationError: String?
    @Published var elevationGainMeters: Double = 0
    @Published var currentAltitudeMeters: Double = 0
    @Published private(set) var routeCoordinates: [CLLocationCoordinate2D] = []
    @Published private(set) var trackingStartedAt: Date?
    
    private let locationManager = CLLocationManager()
    private var lastLocation: CLLocation?
    private var lastAltitude: Double?
    private var lastDistanceBucket: Int = 0
    private var pausedAt: Date?
    private var accumulatedPausedSeconds: TimeInterval = 0
    
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
        lastAltitude = nil
        distanceKm = 0
        lastDistanceBucket = 0
        elevationGainMeters = 0
        currentAltitudeMeters = 0
        routeCoordinates = []
        trackingStartedAt = Date()
        pausedAt = nil
        accumulatedPausedSeconds = 0
        isPaused = false
        locationError = nil
        locationManager.startUpdatingLocation()
        isTracking = true
        RealityMiningManager.shared.trackEvent(name: "run_tracking_start")
    }
    
    func stop() {
        if isPaused, let pausedAt {
            accumulatedPausedSeconds += Date().timeIntervalSince(pausedAt)
            self.pausedAt = nil
        }
        locationManager.stopUpdatingLocation()
        RealityMiningManager.shared.trackEvent(
            name: "run_tracking_stop",
            properties: ["distance_km": distanceKm]
        )
        isPaused = false
        isTracking = false
    }

    func pause() {
        guard isTracking, !isPaused else { return }
        locationManager.stopUpdatingLocation()
        pausedAt = Date()
        isPaused = true
    }

    func resume() {
        guard isTracking, isPaused else { return }
        if let pausedAt {
            accumulatedPausedSeconds += Date().timeIntervalSince(pausedAt)
        }
        self.pausedAt = nil
        locationManager.startUpdatingLocation()
        isPaused = false
    }
    
    func reset() {
        lastLocation = nil
        lastAltitude = nil
        distanceKm = 0
        elevationGainMeters = 0
        currentAltitudeMeters = 0
        routeCoordinates = []
        trackingStartedAt = nil
        pausedAt = nil
        accumulatedPausedSeconds = 0
        isPaused = false
    }

    func elapsedSeconds(now: Date = Date()) -> TimeInterval {
        guard isTracking, let startedAt = trackingStartedAt else { return 0 }
        let raw = max(0, now.timeIntervalSince(startedAt))
        let pausedExtra: TimeInterval
        if isPaused, let pausedAt {
            pausedExtra = accumulatedPausedSeconds + max(0, now.timeIntervalSince(pausedAt))
        } else {
            pausedExtra = accumulatedPausedSeconds
        }
        return max(0, raw - pausedExtra)
    }
}

extension RunTracker: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last, newLocation.horizontalAccuracy >= 0 else { return }
        DispatchQueue.main.async {
            self.currentAltitudeMeters = max(0, newLocation.altitude)
            if let lastCoord = self.routeCoordinates.last {
                let last = CLLocation(latitude: lastCoord.latitude, longitude: lastCoord.longitude)
                if last.distance(from: newLocation) >= 5 {
                    self.routeCoordinates.append(newLocation.coordinate)
                }
            } else {
                self.routeCoordinates.append(newLocation.coordinate)
            }
        }
        if let last = lastLocation {
            let meters = last.distance(from: newLocation)
            if meters > 0 && meters < 500 {
                DispatchQueue.main.async {
                    self.distanceKm += meters / 1000.0
                    let currentBucket = Int(self.distanceKm)
                    if currentBucket > self.lastDistanceBucket {
                        self.lastDistanceBucket = currentBucket
                        RealityMiningManager.shared.trackEvent(
                            name: "distance_bucket_reached",
                            properties: ["distance_bucket_km": currentBucket]
                        )
                    }
                }
            }
            if let prevAltitude = self.lastAltitude {
                let delta = newLocation.altitude - prevAltitude
                if delta > 0 {
                    self.elevationGainMeters += delta
                }
            }
            self.lastAltitude = newLocation.altitude
        }
        lastLocation = newLocation
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.locationError = error.localizedDescription
            RealityMiningManager.shared.trackEvent(
                name: "location_tracking_error",
                properties: ["error_message": error.localizedDescription]
            )
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.locationError = "位置情報が許可されていません"
                RealityMiningManager.shared.trackEvent(
                    name: "location_permission_state",
                    properties: ["state": "denied_or_restricted"]
                )
            }
        case .authorizedAlways, .authorizedWhenInUse:
            RealityMiningManager.shared.trackEvent(
                name: "location_permission_state",
                properties: ["state": "authorized"]
            )
        case .notDetermined:
            RealityMiningManager.shared.trackEvent(
                name: "location_permission_state",
                properties: ["state": "not_determined"]
            )
        default:
            break
        }
    }
}
