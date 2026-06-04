import Foundation
import Observation

/// Gestor de configuraciones persistidas y observables de la aplicación.
@Observable
final class AppSettings {
    var accessibilityTextSizeScale: Double {
        didSet {
            UserDefaults.standard.set(accessibilityTextSizeScale, forKey: "accessibilityTextSizeScale")
        }
    }
    
    init() {
        let stored = UserDefaults.standard.double(forKey: "accessibilityTextSizeScale")
        self.accessibilityTextSizeScale = stored == 0 ? 1.0 : stored
    }
}
