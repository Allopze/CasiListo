import XCTest
@testable import CasiListo

final class SiteLinksTests: XCTestCase {
    func testSupportLinksUseCanonicalDomain() {
        XCTAssertEqual(AppSupportLinks.privacy.absoluteString, "https://casilisto.lat/privacy/")
        XCTAssertEqual(AppSupportLinks.support.absoluteString, "https://casilisto.lat/support/")
    }
}
