import SwiftUI

struct SettingsGestureGuideSection: View {
    var body: some View {
        SettingsSection(title: "GUÍA DE USO") {
            SettingsCard {
                GestureGuideRows()
            }
        }
    }
}
