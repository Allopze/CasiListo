import Foundation

/// Avance de una compra hacia «¡Listo!» (DESIGN.md §2).
///
/// Es la voz del concepto de la app: el nombre «CasiListo» aparece en pantalla
/// exactamente cuando es verdad, con tres cuartos de la compra en el carro.
/// Vive fuera de las vistas para que el panel de la lista, las tarjetas de
/// «Mis Listas» y los tests lean la misma escala.
///
/// Pospuestos y no encontrados no cuentan en ningún lado: no hay que buscarlos
/// más, así que una lista cuyos únicos restos están pospuestos ya está lista.
nonisolated struct ListProgress: Equatable {
    let pending: Int
    let purchased: Int

    /// Tres cuartos de la compra en el carro.
    static let almostDoneThreshold = 0.75

    enum Stage: Equatable {
        case empty
        case notStarted
        case underway
        case almostDone
        case done
    }

    var total: Int { pending + purchased }

    var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(purchased) / Double(total)
    }

    var stage: Stage {
        guard total > 0 else { return .empty }
        if pending == 0 { return .done }
        if purchased == 0 { return .notStarted }
        return fraction >= Self.almostDoneThreshold ? .almostDone : .underway
    }

    /// La voz del panel, a la izquierda. Nunca lleva números: el dato va en
    /// `countLabel`, a la derecha, y el numeral ya cuenta los pendientes.
    var phrase: String {
        switch stage {
        case .empty: return "Lista vacía"
        case .notStarted: return "Todo por comprar"
        case .underway: return "Vas avanzando"
        case .almostDone: return "Casi listo"
        case .done: return "Todo en el carro"
        }
    }

    /// «1 de 363»: cuántos van en el carro. Reemplaza un porcentaje que
    /// redondeaba a «0 %» con un producto ya comprado.
    var countLabel: String {
        "\(purchased) de \(total)"
    }
}
