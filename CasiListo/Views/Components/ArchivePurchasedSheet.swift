import SwiftUI

/// Cierre de la compra: archivar lo comprado, con o sin boleta.
///
/// Era un `confirmationDialog` del sistema. Desde que el panel de progreso es
/// carbón, iOS lo anclaba sobre él: el vidrio del popover tomaba el negro de
/// fondo y las dos opciones, en el oro del tint de la app, medían 1,2:1. Además
/// se veían idénticas, sin opción principal. Una hoja propia fija el contraste
/// y deja claro cuál es el camino recomendado (con boleta).
///
/// Los labels de los botones son los mismos del diálogo: los UI tests tocan
/// «Añadir boleta y archivar» y «Archivar 1 comprado».
struct ArchivePurchasedSheet: View {
    let listTitle: String
    let purchasedCount: Int
    let onArchiveWithReceipt: () -> Void
    let onArchive: () -> Void
    let onCancel: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title) private var badgeSize: CGFloat = 52

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "archivebox.fill")
                        .font(.system(size: badgeSize * 0.42, weight: .semibold))
                        .foregroundStyle(Theme.accentYellow)
                        .frame(width: badgeSize, height: badgeSize)
                        .background(Theme.panel, in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cerrar la compra")
                            .font(Theme.sectionHeaderDynamic)
                            .foregroundStyle(Color.appTextPrimary)
                            .accessibilityAddTraits(.isHeader)
                        Text(
                            SpanishPluralization.count(purchasedCount, singular: "producto comprado", plural: "productos comprados")
                                + (purchasedCount == 1 ? " pasa" : " pasan")
                                + " al historial de «\(listTitle)»."
                        )
                        .font(Theme.bodyDynamic)
                        .foregroundStyle(Color.appTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Button(action: onArchiveWithReceipt) {
                        Label("Añadir boleta y archivar", systemImage: "doc.text.viewfinder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.accentProminent)

                    Text("Con la boleta, CasiListo además registra los precios que pagaste.")
                        .font(Theme.captionDynamic)
                        .foregroundStyle(Color.appTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                }

                Button(action: onArchive) {
                    Text("Archivar " + SpanishPluralization.count(purchasedCount, singular: "comprado", plural: "comprados"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.accentBordered)

                Button(action: onCancel) {
                    Text("Cancelar")
                        .font(Theme.bodyBoldDynamic)
                        .foregroundStyle(Color.appTextSecondary)
                        .frame(maxWidth: .infinity, minHeight: Theme.minimumTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 12)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color.appBackground)
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.appBackground)
    }
}
