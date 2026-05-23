import SwiftUI

/// Barra inferior para la inserción rápida de productos con autocompletado en chips.
struct BottomAddBarView: View {
    @Binding var text: String
    let onAddQuick: () -> Void
    let onAddTapped: () -> Void
    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0
    @State private var suggestions: [String] = []

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
                                        .padding(.horizontal, 12 * CGFloat(accessibilityTextSizeScale))
                                        .padding(.vertical, 6 * CGFloat(accessibilityTextSizeScale))
                                        .glassFilterSurface(cornerRadius: Theme.chipCornerRadius, interactive: true)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, Theme.cardPadding(scale: accessibilityTextSizeScale))
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.top, 4)
                }

                HStack(spacing: 10 * CGFloat(accessibilityTextSizeScale)) {
                    HStack {
                        Image(systemName: "cart.badge.plus")
                            .font(.system(size: 14 * CGFloat(accessibilityTextSizeScale)))
                            .foregroundStyle(Color.appTextSecondary)
                            .padding(.leading, 12 * CGFloat(accessibilityTextSizeScale))

                        TextField("Añadir rápido...", text: $text)
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
                    .frame(height: 40 * CGFloat(accessibilityTextSizeScale))
                    .glassFilterSurface(cornerRadius: Theme.controlCornerRadius(scale: accessibilityTextSizeScale), interactive: true)

                    if !text.trimmingCharacters(in: .whitespaces).isEmpty {
                        Button { onAddQuick() } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 28 * CGFloat(accessibilityTextSizeScale)))
                                .foregroundStyle(Theme.accentYellow)
                                .frame(width: Theme.minimumTouchTarget, height: Theme.minimumTouchTarget)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Añadir instantáneamente")

                        Button { onAddTapped() } label: {
                            Image(systemName: "ellipsis.circle.fill")
                                .font(.system(size: 28 * CGFloat(accessibilityTextSizeScale)))
                                .foregroundStyle(Color.appTextSecondary)
                                .frame(width: Theme.minimumTouchTarget, height: Theme.minimumTouchTarget)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Añadir con detalles")
                    } else {
                        Button { onAddTapped() } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 28 * CGFloat(accessibilityTextSizeScale)))
                                .foregroundStyle(Theme.accentYellow)
                                .frame(width: Theme.minimumTouchTarget, height: Theme.minimumTouchTarget)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Añadir producto")
                    }
                }
                .padding(.horizontal, Theme.cardPadding(scale: accessibilityTextSizeScale))
                .padding(.top, 4)
                .padding(.bottom, 8 * CGFloat(accessibilityTextSizeScale))
            }
            .background(Color.appBackground.opacity(0.85))
        }
        .task(id: text) {
            try? await Task.sleep(for: .milliseconds(150))
            suggestions = SuggestedProducts.suggestions(for: text)
        }
    }
}
