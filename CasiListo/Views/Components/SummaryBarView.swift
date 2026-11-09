import SwiftUI

/// Panel que encabeza la lista: cuenta hacia atrás hasta «¡Listo!».
///
/// Antes era una línea de `caption` gris («355 pendientes») y una barra de
/// 5 pt que solo aparecía tras el primer comprado: el dato que la persona
/// busca en el pasillo era el texto más pequeño de la pantalla. Ahora el
/// número de pendientes es el protagonista, la frase sigue la escala de
/// `ListProgress` y, con el último producto, el panel se inunda de amarillo y
/// el CTA de archivar sube a primer plano (DESIGN.md §2).
struct SummaryBarView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let pendingCount: Int
    let purchasedCount: Int
    @Binding var showPurchased: Bool
    var onArchivePurchased: (() -> Void)?

    @ScaledMetric(relativeTo: .largeTitle) private var numeralSize: CGFloat = 64
    @ScaledMetric(relativeTo: .caption) private var progressHeight: CGFloat = 8
    @ScaledMetric(relativeTo: .body) private var panelPadding: CGFloat = 20

    private var progress: ListProgress {
        ListProgress(pending: pendingCount, purchased: purchasedCount)
    }

    private var isDone: Bool { progress.stage == .done }

    // Con todo en el carro el panel se invierte: amarillo de relleno y tinta
    // oscura (10,7:1). Mientras tanto, carbón con tinta clara.
    private var ground: Color { isDone ? Theme.accentYellow : Theme.panel }
    private var ink: Color { isDone ? Theme.onAccent : Theme.onPanel }
    private var inkSecondary: Color { isDone ? Theme.onAccent : Theme.onPanelSecondary }
    private var track: Color { isDone ? Theme.onAccent.opacity(0.14) : Theme.panelTrack }
    private var fill: Color { isDone ? Theme.onAccent : Theme.accentYellow }

    var body: some View {
        // El numeral queda solo arriba: es la imagen del panel. Debajo, la
        // barra; luego la voz (izquierda) y el dato (derecha); al final, las
        // acciones sobre lo comprado.
        VStack(alignment: .leading, spacing: 16) {
            headline

            progressBar

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    phraseText
                    Spacer(minLength: 8)
                    countText
                }
                VStack(alignment: .leading, spacing: 4) {
                    phraseText
                    countText
                }
            }

            actionsRow
        }
        .padding(panelPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ground, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .strokeBorder(isDone ? Color.clear : Theme.panelEdge, lineWidth: 1)
        }
        .animation(Theme.panelAnimation(reduceMotion: reduceMotion), value: isDone)
        .onChange(of: isDone) { _, done in
            if done { HapticFeedback.success() }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Numeral

    @ViewBuilder
    private var headline: some View {
        if isDone {
            HStack(alignment: .center, spacing: 12) {
                DrawnCheckBadge()
                Text("¡Listo!")
                    .font(Theme.displayNumeral(size: numeralSize * 0.75))
                    .tracking(-1.5)
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("¡Listo! No quedan productos pendientes")
            .accessibilityIdentifier("progress-panel-headline")
        } else {
            VStack(alignment: .leading, spacing: 0) {
                // El numeral lleva el label completo: VoiceOver y los UI tests
                // leen «355 pendientes» en un solo elemento.
                Text("\(pendingCount)")
                    .font(Theme.displayNumeral(size: numeralSize))
                    .tracking(-2)
                    .foregroundStyle(Theme.accentYellow)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText(value: Double(pendingCount)))
                    .animation(Theme.tickAnimation(reduceMotion: reduceMotion), value: pendingCount)
                    .accessibilityLabel(
                        SpanishPluralization.count(pendingCount, singular: "pendiente", plural: "pendientes")
                    )
                    .accessibilityIdentifier("progress-panel-headline")

                Text(pendingCount == 1 ? "pendiente" : "pendientes")
                    .font(Theme.bodyBoldDynamic)
                    .foregroundStyle(ink)
                    .accessibilityHidden(true)
            }
        }
    }

    // MARK: - Progreso

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    .fill(fill)
                    .frame(width: progress.fraction > 0 ? max(progressHeight, proxy.size.width * progress.fraction) : 0)
            }
        }
        .frame(height: progressHeight)
        .animation(Theme.panelAnimation(reduceMotion: reduceMotion), value: progress.fraction)
        .accessibilityElement()
        .accessibilityLabel("Progreso de la compra")
        .accessibilityValue(
            "\(purchasedCount) de "
                + SpanishPluralization.count(progress.total, singular: "producto comprado", plural: "productos comprados")
        )
    }

    private var phraseText: some View {
        Text(progress.phrase)
            .font(Theme.bodyBoldDynamic)
            // «Casi listo» es el único momento en que la frase se pinta de
            // acento: es el nombre de la app diciendo la verdad.
            .foregroundStyle(progress.stage == .almostDone ? Theme.accentYellow : ink)
            .contentTransition(.opacity)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var countText: some View {
        Text(progress.countLabel)
            .font(Theme.receiptMonoCaption.weight(.semibold))
            .foregroundStyle(inkSecondary)
            .contentTransition(.numericText(value: Double(purchasedCount)))
            .animation(Theme.tickAnimation(reduceMotion: reduceMotion), value: purchasedCount)
            .accessibilityLabel("\(purchasedCount) de \(progress.total) en el carro")
    }

    /// A medio camino: archivar y ocultar, dos enlaces discretos en una fila.
    /// Completa: archivar sube a CTA de relleno y ocultar desaparece (ocultar
    /// todo dejaría la lista vacía bajo un panel que dice «¡Listo!»).
    @ViewBuilder
    private var actionsRow: some View {
        if isDone {
            archiveButton
        } else if purchasedCount > 0 {
            HStack(spacing: 10) {
                archiveButton
                Spacer(minLength: 0)
                visibilityButton
            }
        }
    }

    // MARK: - Controles

    @ViewBuilder
    private var visibilityButton: some View {
        // Sin comprados no hay nada que mostrar u ocultar.
        if purchasedCount > 0 {
            Button {
                HapticFeedback.selection()
                withAnimation(Theme.defaultAnimation(reduceMotion: reduceMotion)) {
                    showPurchased.toggle()
                }
            } label: {
                // Solo ícono: junto a «Archivar» la etiqueta completa no cabía
                // y se leía como pie de foto. VoiceOver lleva el texto entero.
                Image(systemName: showPurchased ? "eye.slash" : "eye")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ink)
                    .frame(width: Theme.minimumTouchTarget, height: Theme.minimumTouchTarget)
                    .background(track, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel(showPurchased ? "Ocultar comprados" : "Mostrar comprados")
        }
    }

    /// A medio camino archivar es una opción discreta; con todo en el carro
    /// es el siguiente paso natural y sube a CTA de relleno.
    @ViewBuilder
    private var archiveButton: some View {
        if purchasedCount > 0, let archive = onArchivePurchased {
            let title = "Archivar " + SpanishPluralization.count(purchasedCount, singular: "comprado", plural: "comprados")
            Button {
                HapticFeedback.selection()
                archive()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isDone ? "archivebox.fill" : "archivebox")
                        .accessibilityHidden(true)
                    Text(title)
                        .fixedSize(horizontal: false, vertical: true)
                    if isDone {
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.right")
                            .accessibilityHidden(true)
                    }
                }
                .font(isDone ? Theme.bodyBoldDynamic : Theme.captionDynamic.weight(.semibold))
                .foregroundStyle(isDone ? Theme.accentYellow : ink)
                .padding(.horizontal, isDone ? 18 : 14)
                .frame(maxWidth: isDone ? .infinity : nil, minHeight: isDone ? 52 : Theme.minimumTouchTarget, alignment: .leading)
                .background(isDone ? Theme.panel : track, in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel(
                "Archivar "
                    + SpanishPluralization.count(purchasedCount, singular: "producto comprado", plural: "productos comprados")
            )
        }
    }
}

// MARK: - Visto dibujado

/// El visto del logo trazándose dentro de un círculo carbón: la firma del
/// momento «¡Listo!». Con Reduce Motion aparece ya dibujado.
struct DrawnCheckBadge: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 48
    @State private var drawn = false

    var body: some View {
        ZStack {
            Circle().fill(Theme.panel)
            CheckmarkShape()
                .trim(from: 0, to: drawn ? 1 : 0)
                .stroke(Theme.accentYellow, style: StrokeStyle(lineWidth: size * 0.11, lineCap: .round, lineJoin: .round))
                .padding(size * 0.27)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else {
                drawn = true
                return
            }
            withAnimation(Theme.tickAnimation.delay(0.18)) { drawn = true }
        }
    }
}

// MARK: - Presión

/// Respuesta al toque de los controles propios: hunde un 3 % con el resorte
/// del visto. Los botones de sistema ya traen la suya.
struct PressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(Theme.tickAnimation(reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}
