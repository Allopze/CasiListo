import Foundation
import CoreLocation
import UserNotifications
import SwiftData
import Observation
import os.log

/// Servicio encargado de registrar y gestionar alertas geolocalizadas cuando el usuario
/// pasa cerca de un supermercado con artículos pendientes.
@Observable
@MainActor
final class GeofenceService: NSObject, CLLocationManagerDelegate {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "CasiListo", category: "GeofenceService")
    static let shared = GeofenceService()
    
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    private let locationManager = CLLocationManager()
    private var modelContainer: ModelContainer?
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = locationManager.authorizationStatus
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
            Self.logger.error("Error solicitando notificaciones: \(error)")
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
    
    /// Cuenta los productos pendientes para una tienda en la lista activa.
    ///
    /// - Note: Crea un `ModelContext` independiente porque este método puede invocarse
    ///   desde el delegate de `CLLocationManager` en background. Esto garantiza thread safety,
    ///   pero implica que cambios no persistidos en el contexto principal no serán visibles.
    ///   En la práctica, esto es un edge case menor: el usuario tendría que tener items
    ///   sin guardar *y* entrar a un geofence simultáneamente.
    private func fetchPendingCount(for store: Store) -> Int {
        guard let container = modelContainer else { return 0 }
        let context = ModelContext(container)

        let activeStatusRawValue = ShoppingListStatus.active.rawValue
        var listDescriptor = FetchDescriptor<ShoppingList>()
        listDescriptor.predicate = #Predicate<ShoppingList> { list in
            list.statusRawValue == activeStatusRawValue
        }

        guard let activeList = try? context.fetch(listDescriptor).first else {
            return 0
        }
        
        let storeRawValue = store.rawValue
        let pendingStatusRawValue = ShoppingItemStatus.pending.rawValue
        let activeListID = activeList.id
        
        var descriptor = FetchDescriptor<ShoppingItem>()
        descriptor.predicate = #Predicate<ShoppingItem> { item in
            item.listID == activeListID
                && item.storeRawValue == storeRawValue
                && !item.storedIsPurchased
                && (item.statusRawValue == nil || item.statusRawValue == pendingStatusRawValue)
        }
        
        do {
            return try context.fetchCount(descriptor)
        } catch {
            Self.logger.error("Error al buscar productos para geofence: \(error)")
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
                Self.logger.error("Error enviando notificación: \(error)")
            }
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        self.authorizationStatus = status
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
