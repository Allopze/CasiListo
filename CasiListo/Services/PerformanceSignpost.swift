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
}
