import Foundation

nonisolated enum SpanishPluralization {
    static func count(_ value: Int, singular: String, plural: String? = nil) -> String {
        let noun = value == 1 ? singular : (plural ?? "\(singular)s")
        return "\(value) \(noun)"
    }
}
