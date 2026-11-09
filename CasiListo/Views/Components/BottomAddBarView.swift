import SwiftUI
import SwiftData

/// Barra inferior para la inserción rápida de productos con autocompletado en chips.
struct BottomAddBarView: View {
    @Binding var text: String
    let onAddQuick: () -> Void
    let onAddTapped: () -> Void
    @State private var suggestions: [String] = []
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \ProductCatalogItem.name, order: .forward) private var catalogItems: [ProductCatalogItem]

    @ScaledMetric(relativeTo: .body) private var chipPaddingHorizontal: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var chipPaddingVertical: CGFloat = 6
    @ScaledMetric(relativeTo: .body) private var cardPadding: CGFloat = Theme.cardPadding
    @ScaledMetric(relativeTo: .body) private var hStackSpacing: CGFloat = 10
    @ScaledMetric(relativeTo: .body) private var cartIconSize: CGFloat = 14
    @ScaledMetric(relativeTo: .body) private var cartIconLeadingPadding: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var textFieldHeight: CGFloat = 40
    @ScaledMetric(relativeTo: .body) private var controlCornerRadius: CGFloat = Theme.controlCornerRadius
    @ScaledMetric(relativeTo: .body) private var actionButtonSymbolSize: CGFloat = 28
    @ScaledMetric(relativeTo: .body) private var actionButtonSize: CGFloat = Theme.minimumTouchTarget
    @ScaledMetric(relativeTo: .body) private var bottomPadding: CGFloat = 8

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            VStack(spacing: 6) {
                if !text.isEmpty && !suggestions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(suggestions.prefix(5), id: \.self) { suggestion in
                                Button {
                                    HapticFeedback.selection()
                                    text = suggestion
                                    onAddQuick()
                                } label: {
                                    Text(suggestion)
                                        .font(Theme.chipDynamic)
                                        .foregroundStyle(Color.appTextPrimary)
                                        .padding(.horizontal, chipPaddingHorizontal)
                                        .padding(.vertical, chipPaddingVertical)
                                        .glassFilterSurface(cornerRadius: Theme.chipCornerRadius, interactive: true)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, cardPadding)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.top, 4)
                }

                inputRow
                    .padding(.horizontal, cardPadding)
                .padding(.top, 4)
                .padding(.bottom, bottomPadding)
            }
            .background {
                Color.appBackground
                    .overlay(alignment: .top) {
                        Color.appSeparator.opacity(0.7)
                            .frame(height: 1)
                    }
            }
        }
        .task(id: text) {
            try? await Task.sleep(for: .milliseconds(150))
            suggestions = CatalogService.suggestions(for: text, in: catalogItems)
        }
    }

    /// Un solo `TextField` en un `AnyLayout`, que conserva la identidad de
    /// sus hijos al cambiar de eje. Antes era `ViewThatFits` con dos copias
    /// del campo: al escribir la primera letra aparecía el segundo botón, el
    /// ancho *ideal* del campo (el de su placeholder) ya no cabía en la fila,
    /// `ViewThatFits` saltaba a la copia vertical y el campo nuevo nacía sin
    /// foco: el teclado se cerraba tras cada primera letra. El eje lo decide
    /// el tamaño de texto, que no cambia mientras se escribe.
    private var inputRow: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .trailing, spacing: 8))
            : AnyLayout(HStackLayout(spacing: hStackSpacing))
        return layout {
            inputField
            HStack(spacing: hStackSpacing) {
                actionButtons
            }
        }
    }

    private var inputField: some View {
        HStack {
            Image(systemName: "cart.badge.plus")
                .font(.system(size: cartIconSize))
                .foregroundStyle(Color.appTextSecondary)
                .padding(.leading, cartIconLeadingPadding)

            // Prompt con la tinta tenue de la app: el placeholder del sistema
            // medía ~2:1 sobre el vidrio, y este enseña la sintaxis.
            TextField(
                text: $text,
                prompt: Text("Añade “2kg arroz” o “pan x3”…").foregroundStyle(Color.appTextSecondary)
            ) {
                Text("Añadir producto rápido")
            }
                .font(Theme.bodyDynamic)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .accessibilityIdentifier("quick-add-field")
                .onSubmit {
                    if !text.trimmingCharacters(in: .whitespaces).isEmpty {
                        onAddQuick()
                    }
                }
        }
        .frame(maxWidth: .infinity, minHeight: textFieldHeight)
        .glassFilterSurface(cornerRadius: controlCornerRadius, interactive: true)
        .layoutPriority(1)
    }

    @ViewBuilder
    private var actionButtons: some View {
        if !text.trimmingCharacters(in: .whitespaces).isEmpty {
            Button { onAddQuick() } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: actionButtonSymbolSize))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Theme.onAccent, Theme.accentYellow)
                    .frame(width: actionButtonSize, height: actionButtonSize)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Añadir instantáneamente")

            Button { onAddTapped() } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: actionButtonSymbolSize))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.appCardBackground, Color.appTextSecondary)
                    .frame(width: actionButtonSize, height: actionButtonSize)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Añadir con detalles")
        } else {
            Button { onAddTapped() } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: actionButtonSymbolSize))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Theme.onAccent, Theme.accentYellow)
                    .frame(width: actionButtonSize, height: actionButtonSize)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Añadir producto")
            .accessibilityIdentifier("quick-add-product")
        }
    }
}
