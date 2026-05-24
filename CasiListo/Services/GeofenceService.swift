import Foundation
import CoreLocation
import UserNotifications
import SwiftData

/// Servicio encargado de registrar y gestionar alertas geolocalizadas cuando el usuario
/// pasa cerca de un supermercado con artículos pendientes.
@MainActor
final class GeofenceService: NSObject, CLLocationManagerDelegate {
    static let shared = GeofenceService()
    
    private let locationManager = CLLocationManager()
    private var modelContainer: ModelContainer?
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }
    
    func initialize(with container: ModelContainer) {
        self.modelContainer = container
        
        // Si el geofencing está activo en los ajustes, iniciar monitoreo
        if UserDefaults.standard.bool(forKey: "geofencing_enabled") {
            startMonitoringAll()
        }
    }
    
    func requestNotificationPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Error solicitando notificaciones: \(error)")
            return false
        }
    }

    func requestWhenInUsePermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func requestAlwaysPermissionForBackgroundReminders() {
        locationManager.requestAlwaysAuthorization()
    }

    func requestPermissions() {
        Task { @MainActor in
            _ = await requestNotificationPermission()
            requestWhenInUsePermission()
        }
    }
    
    func startMonitoringAll() {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }
        
        stopMonitoringAll()
        
        for store in Store.allCases {
            let coordinate = CLLocationCoordinate2D(latitude: store.latitude, longitude: store.longitude)
            let region = CLCircularRegion(
                center: coordinate,
                radius: store.geofenceRadius,
                identifier: store.rawValue
            )
            region.notifyOnEntry = true
            region.notifyOnExit = false
            
            locationManager.startMonitoring(for: region)
        }
    }
    
    func stopMonitoringAll() {
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let store = Store(rawValue: region.identifier) else { return }
        
        // Consultar productos pendientes para esta tienda
        let pendingCount = fetchPendingCount(for: store)
        
        if pendingCount > 0 {
            sendNotification(for: store, count: pendingCount)
        }
    }
    
    private func fetchPendingCount(for store: Store) -> Int {
        guard let container = modelContainer else { return 0 }
        let context = ModelContext(container)
        
        let storeRawValue = store.rawValue
        let pendingStatusRawValue = ShoppingItemStatus.pending.rawValue
        
        // Usar FetchDescriptor simple
        var descriptor = FetchDescriptor<ShoppingItem>()
        descriptor.predicate = #Predicate<ShoppingItem> { item in
            item.storeRawValue == storeRawValue
                && !item.isPurchased
                && (item.statusRawValue == nil || item.statusRawValue == pendingStatusRawValue)
        }
        
        do {
            let items = try context.fetch(descriptor)
            return items.count
        } catch {
            print("Error al buscar productos para geofence: \(error)")
            return 0
        }
    }
    
    private func sendNotification(for store: Store, count: Int) {
        let content = UNMutableNotificationContent()
        content.title = "📍 Cerca de \(store.displayName)"
        content.body = "Tienes \(count) \(count == 1 ? "producto pendiente" : "productos pendientes") por comprar aquí."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "geofence_\(store.rawValue)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil // Disparar de inmediato
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error enviando notificación: \(error)")
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            if UserDefaults.standard.bool(forKey: "geofencing_enabled") {
                startMonitoringAll()
            }
        } else if status == .denied || status == .restricted {
            // Si el permiso fue revocado, desactivar en UserDefaults
            UserDefaults.standard.set(false, forKey: "geofencing_enabled")
            stopMonitoringAll()
        }
    }
}
