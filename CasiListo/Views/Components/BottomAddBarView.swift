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

    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0

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
                                        .font(Theme.chipFont(scale: accessibilityTextSizeScale))
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
                            .font(.system(size: cartIconSize * CGFloat(accessibilityTextSizeScale)))
                            .foregroundStyle(Color.appTextSecondary)
                            .padding(.leading, cartIconLeadingPadding)

                        TextField("Añade “2kg arroz” o “pan x3”…", text: $text)
                            .font(Theme.bodyFont(scale: accessibilityTextSizeScale))
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
                                .font(.system(size: actionButtonSymbolSize * CGFloat(accessibilityTextSizeScale)))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(Color(hex: "1A1A1A"), Theme.accentYellow)
                                .frame(width: actionButtonSize * CGFloat(accessibilityTextSizeScale), height: actionButtonSize * CGFloat(accessibilityTextSizeScale))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Añadir instantáneamente")

                        Button { onAddTapped() } label: {
                            Image(systemName: "ellipsis.circle.fill")
                                .font(.system(size: actionButtonSymbolSize * CGFloat(accessibilityTextSizeScale)))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(Color.appCardBackground, Color.appTextSecondary)
                                .frame(width: actionButtonSize * CGFloat(accessibilityTextSizeScale), height: actionButtonSize * CGFloat(accessibilityTextSizeScale))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Añadir con detalles")
                    } else {
                        Button { onAddTapped() } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: actionButtonSymbolSize * CGFloat(accessibilityTextSizeScale)))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(Color(hex: "1A1A1A"), Theme.accentYellow)
                                .frame(width: actionButtonSize * CGFloat(accessibilityTextSizeScale), height: actionButtonSize * CGFloat(accessibilityTextSizeScale))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Añadir producto")
                        .accessibilityIdentifier("quick-add-product")
                    }
                }
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
            suggestions = SuggestedProducts.suggestions(for: text)
        }
    }
}
