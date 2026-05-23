import XCTest
import SwiftData
@testable import CasiListo

@MainActor
final class CasiListoTests: XCTestCase {

    func testPriceTotals() {
        let viewModel = ShoppingListViewModel()
        let items = [
            ShoppingItem(name: "Tomates", isPurchased: false, price: 1.50),
            ShoppingItem(name: "Leche", isPurchased: false, price: 2.00),
            ShoppingItem(name: "Pan", isPurchased: true, price: 1.20),
            ShoppingItem(name: "Galletas", isPurchased: true, price: nil)
        ]
        
        XCTAssertEqual(viewModel.pendingTotal(from: items), 3.50, accuracy: 0.001)
        XCTAssertEqual(viewModel.purchasedTotal(from: items), 1.20, accuracy: 0.001)
        XCTAssertEqual(viewModel.grandTotal(from: items), 4.70, accuracy: 0.001)
    }

    func testItemCounts() {
        let viewModel = ShoppingListViewModel()
        let items = [
            ShoppingItem(name: "Tomates", isPurchased: false),
            ShoppingItem(name: "Leche", isPurchased: false),
            ShoppingItem(name: "Pan", isPurchased: true)
        ]
        
        let counts = viewModel.itemCounts(from: items)
        XCTAssertEqual(counts.pending, 2)
        XCTAssertEqual(counts.purchased, 1)
    }

    func testNextSortOrder() {
        let viewModel = ShoppingListViewModel()
        let items = [
            ShoppingItem(name: "Tomates", category: .frutasVerduras, sortOrder: 0),
            ShoppingItem(name: "Lechuga", category: .frutasVerduras, sortOrder: 2),
            ShoppingItem(name: "Leche", category: .lacteosHuevos, sortOrder: 1)
        ]
        
        XCTAssertEqual(viewModel.nextSortOrder(for: .frutasVerduras, in: items), 3)
        XCTAssertEqual(viewModel.nextSortOrder(for: .lacteosHuevos, in: items), 2)
        XCTAssertEqual(viewModel.nextSortOrder(for: .despensa, in: items), 0)
    }
}
