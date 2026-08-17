import SwiftUI

/// Botón reutilizable para reproducir y detener notas de voz de forma interactiva con un waveform animado.
struct VoiceNotePlayerButton: View {
    let filename: String
    
    @State private var waveAnimation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Environment(VoiceNoteService.self) private var voiceNoteService
    @State private var errorMessage: String?
    @AccessibilityFocusState private var shouldFocusPlaybackButton: Bool
    private let waveBarHeights: [CGFloat] = [8, 16, 11, 18]
    
    var body: some View {
        let isPlaying = voiceNoteService.currentlyPlayingFilename == filename
        
        Button {
            HapticFeedback.selection()
            if isPlaying {
                voiceNoteService.stopPlaying()
            } else {
                if case .failure(let error) = voiceNoteService.startPlaying(filename: filename) {
                    errorMessage = error.errorDescription
                }
            }
        } label: {
            HStack(spacing: 8) {
                // Waveform animado si está reproduciendo, o ícono de play si no
                if isPlaying {
                    HStack(spacing: 2) {
                        ForEach(waveBarHeights.indices, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(.white)
                                .frame(width: 2, height: reduceMotion ? 12 : (waveAnimation ? waveBarHeights[index] : 10))
                                .animation(
                                    reduceMotion
                                        ? nil
                                        : Animation.easeInOut(duration: 0.3)
                                            .repeatForever(autoreverses: true)
                                            .delay(Double(index) * 0.08),
                                    value: waveAnimation
                                )
                        }
                    }
                    .frame(width: 16, height: 20)
                    .onAppear {
                        if !reduceMotion {
                            waveAnimation = true
                        }
                    }
                    .onDisappear {
                        waveAnimation = false
                    }
                } else {
                    Image(systemName: "waveform")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.accentInteractive)
                }
            }
            .frame(
                width: max(Theme.minimumTouchTarget, 32),
                height: max(Theme.minimumTouchTarget, 32)
            )
            .background(isPlaying ? Color.red.opacity(0.85) : Theme.accentYellow.opacity(0.12))
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPlaying ? "Detener nota de voz" : "Reproducir nota de voz")
        .accessibilityFocused($shouldFocusPlaybackButton)
        .alert(
            "No se pudo reproducir la nota",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("Intentar nuevamente") { retryPlayback() }
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Inténtalo nuevamente.")
        }
        .onChange(of: errorMessage) { oldValue, newValue in
            if oldValue != nil, newValue == nil {
                shouldFocusPlaybackButton = true
            }
        }
    }

    private func retryPlayback() {
        if case .failure(let error) = voiceNoteService.startPlaying(filename: filename) {
            errorMessage = error.errorDescription
        }
    }
}
