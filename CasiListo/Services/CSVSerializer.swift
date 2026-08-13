import Foundation

/// Serializador CSV RFC 4180 para exportaciones que se abren de forma segura
/// en Numbers, Excel y Google Sheets.
nonisolated enum CSVSerializer {
    static func document(rows: [[String]]) -> String {
        rows.map { row in row.map(escapedField).joined(separator: ",") }
            .joined(separator: "\r\n")
            + "\r\n"
    }

    static func escapedField(_ value: String) -> String {
        let protectedValue = protectFromFormulaInjection(value)
        let escaped = protectedValue.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private static func protectFromFormulaInjection(_ value: String) -> String {
        guard let first = value.first, ["=", "+", "-", "@"].contains(first) else {
            return value
        }
        return "'\(value)"
    }
}
