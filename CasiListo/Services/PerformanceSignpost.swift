import os.signpost

/// Puntos de interés para medir las interacciones principales en Instruments.
@MainActor
enum PerformanceSignpost {
    private static let log = OSLog(subsystem: "com.allopze.CasiListo", category: .pointsOfInterest)

    static func measure<T>(_ name: StaticString, _ operation: () -> T) -> T {
        let identifier = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: name, signpostID: identifier)
        defer { os_signpost(.end, log: log, name: name, signpostID: identifier) }
        return operation()
    }

    /// Variante para trabajo que corre fuera del hilo principal, como el
    /// reconocimiento de una boleta: sin esto no hay forma de saber cuánto
    /// tarda ni cuántas líneas se están descartando.
    nonisolated static func measureOffMain<T>(_ name: StaticString, _ operation: () throws -> T) rethrows -> T {
        let log = OSLog(subsystem: "com.allopze.CasiListo", category: .pointsOfInterest)
        let identifier = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: name, signpostID: identifier)
        defer { os_signpost(.end, log: log, name: name, signpostID: identifier) }
        return try operation()
    }
}
