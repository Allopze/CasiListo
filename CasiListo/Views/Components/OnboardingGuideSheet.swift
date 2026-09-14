import SwiftUI

/// Guía de primer uso: aparece una sola vez, la primera vez que la persona ve
/// una lista con productos (CASI-011). El contenido es el mismo que ya vivía
/// enterrado en Ajustes — `GestureGuideRows`, sin duplicar el texto.
///
/// A diferencia de los sheets add/edit del proyecto, esto no edita nada: sin
/// `Form(.grouped)` ni toolbar "Cancelar"/"Guardar", solo un botón "Entendido".
struct OnboardingGuideSheet: View {
    let onDismiss: () -> Void

    @ScaledMetric(relativeTo: .body) private var logoSize: CGFloat = 56

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    LogoView(size: logoSize)

                    VStack(spacing: 6) {
                        Text("Así funciona CasiListo")
                            .font(Theme.sectionHeaderDynamic)
                            .foregroundStyle(Color.appTextPrimary)

                        Text("Cuatro gestos cubren casi todo lo que vas a necesitar.")
                            .font(Theme.bodyDynamic)
                            .foregroundStyle(Color.appTextSecondary)
                            .multilineTextAlignment(.center)
                    }

                    GestureGuideRows()
                        .padding(20)
                        .background(Color.appCardBackground, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                }
                .padding(24)
            }
            .background(Color.appBackground)
            .safeAreaInset(edge: .bottom) {
                Button {
                    onDismiss()
                } label: {
                    Text("Entendido")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.accentProminent)
                .controlSize(.large)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.appBackground)
                .accessibilityIdentifier("onboarding-dismiss")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("onboarding-guide")
    }
}
