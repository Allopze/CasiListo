import Foundation

/// El único deep link público de CasiListo 1.0.
enum AppRoute: Equatable {
    case list

    init?(url: URL) {
        guard url.scheme?.lowercased() == "casilisto",
              url.host?.lowercased() == "list",
              (url.path.isEmpty || url.path == "/"),
              url.query == nil,
              url.fragment == nil
        else {
            return nil
        }
        self = .list
    }
}
