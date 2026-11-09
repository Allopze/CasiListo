import SwiftUI

struct SettingsCategoriesSection: View {

    var body: some View {
        SettingsSection(title: "CATEGORÍAS") {
            NavigationLink {
                CategoryManagementView()
            } label: {
                SettingsCard {
                    SettingsLinkRow(
                        title: "Administrar categorías",
                        detail: "Crea, edita, ordena o elimina las categorías de tus productos.",
                        symbol: "tag.fill"
                    )
                }
            }
            .buttonStyle(.plain)
        }
    }
}
