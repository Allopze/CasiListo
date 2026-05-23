import Foundation
import SwiftUI

/// Configuración de presupuestos por supermercado.
struct BudgetConfig {
    static let totalKey = "budget_total"
    static let jumboKey = "budget_jumbo"
    static let liderKey = "budget_lider"
    static let warningThresholdKey = "budget_warning_threshold"
    static let isEnabledKey = "budget_is_enabled"
    
    static let defaultTotal: Double = 200000
    static let defaultJumbo: Double = 150000
    static let defaultLider: Double = 50000
    static let defaultWarningThreshold: Double = 0.8
}

extension Double {
    /// Formatea un valor monetario como Peso Chileno (CLP) con separadores de miles y sin decimales.
    /// Ejemplo: 150000.0 -> "$150.000"
    var formattedCLP: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        formatter.locale = Locale(identifier: "es_CL")
        return formatter.string(from: NSNumber(value: self)) ?? "$\(Int(self))"
    }
}

extension Optional where Wrapped == Double {
    /// Formatea el precio opcional como CLP, o devuelve cadena vacía.
    var formattedCLPOrEmpty: String {
        self?.formattedCLP ?? ""
    }
}
