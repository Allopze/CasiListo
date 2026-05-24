import SwiftUI
import SwiftData

#if DEBUG
@MainActor
enum PreviewFixtures {
    static var shoppingItems: [ShoppingItem] {
        [
            ShoppingItem(
                name: "Tomates",
                quantity: "1 kg",
                note: "Maduros pero firmes",
                sortOrder: 0
            ),
            ShoppingItem(
                name: "Leche",
                quantity: "2",
                sortOrder: 0
            ),
            ShoppingItem(
                name: "Pasta",
                quantity: "500 g",
                isPurchased: true,
                sortOrder: 0
            )
        ]
    }

    static func modelContainer(seed items: [ShoppingItem] = []) -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: ShoppingItem.self,
            ShoppingList.self,
            ProductCatalogItem.self,
            Category.self,
            configurations: configuration
        )

        let context = container.mainContext
        CategoryBootstrapService.bootstrap(context: context)

        for item in items {
            context.insert(item)
        }

        return container
    }
}

#Preview("Lista con productos") {
    ContentView()
        .modelContainer(PreviewFixtures.modelContainer(seed: PreviewFixtures.shoppingItems))
}

#Preview("Lista vacía") {
    ContentView()
        .modelContainer(PreviewFixtures.modelContainer())
}

#Preview("Nuevo producto") {
    AddEditItemSheet(
        mode: .add,
        activeList: nil,
        allItems: PreviewFixtures.shoppingItems,
        viewModel: ShoppingListViewModel()
    )
    .modelContainer(PreviewFixtures.modelContainer())
}

#Preview("Editar producto") {
    AddEditItemSheet(
        mode: .edit(PreviewFixtures.shoppingItems[0]),
        activeList: nil,
        allItems: PreviewFixtures.shoppingItems,
        viewModel: ShoppingListViewModel()
    )
    .modelContainer(PreviewFixtures.modelContainer(seed: PreviewFixtures.shoppingItems))
}
#endif
