import SwiftUI

/// Vista horizontal que muestra sugerencias de productos en chips para autocompletado en la hoja de añadir/editar.
struct SuggestionsListView: View {
    let suggestions: [String]
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            AdaptiveGlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(suggestions.prefix(8), id: \.self) { suggestion in
                        Button {
                            HapticFeedback.selection()
                            onSelect(suggestion)
                        } label: {
                            Text(suggestion)
                                .font(Theme.chipDynamic)
                                .foregroundStyle(Color.appTextPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .glassFilterSurface(cornerRadius: Theme.chipCornerRadius, interactive: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}
