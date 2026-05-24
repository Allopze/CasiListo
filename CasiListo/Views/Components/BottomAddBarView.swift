import SwiftUI

/// Barra inferior para la inserción rápida de productos con autocompletado en chips.
struct BottomAddBarView: View {
    @Binding var text: String
    let onAddQuick: () -> Void
    let onAddTapped: () -> Void
    @State private var suggestions: [String] = []

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
        AdaptiveGlassEffectContainer(spacing: 8) {
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

                HStack(spacing: hStackSpacing) {
                    HStack {
                        Image(systemName: "cart.badge.plus")
                            .font(.system(size: cartIconSize))
                            .foregroundStyle(Color.appTextSecondary)
                            .padding(.leading, cartIconLeadingPadding)

                        TextField("Añadir rápido...", text: $text)
                            .font(Theme.bodyDynamic)
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .onSubmit {
                                if !text.trimmingCharacters(in: .whitespaces).isEmpty {
                                    onAddQuick()
                                }
                            }
                    }
                    .frame(height: textFieldHeight)
                    .glassFilterSurface(cornerRadius: controlCornerRadius, interactive: true)

                    if !text.trimmingCharacters(in: .whitespaces).isEmpty {
                        Button { onAddQuick() } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: actionButtonSymbolSize))
                                .foregroundStyle(Theme.accentYellow)
                                .frame(width: actionButtonSize, height: actionButtonSize)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Añadir instantáneamente")

                        Button { onAddTapped() } label: {
                            Image(systemName: "ellipsis.circle.fill")
                                .font(.system(size: actionButtonSymbolSize))
                                .foregroundStyle(Color.appTextSecondary)
                                .frame(width: actionButtonSize, height: actionButtonSize)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Añadir con detalles")
                    } else {
                        Button { onAddTapped() } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: actionButtonSymbolSize))
                                .foregroundStyle(Theme.accentYellow)
                                .frame(width: actionButtonSize, height: actionButtonSize)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Añadir producto")
                    }
                }
                .padding(.horizontal, cardPadding)
                .padding(.top, 4)
                .padding(.bottom, bottomPadding)
            }
            .background(Color.appBackground.opacity(0.85))
        }
        .task(id: text) {
            try? await Task.sleep(for: .milliseconds(150))
            suggestions = SuggestedProducts.suggestions(for: text)
        }
    }
}
