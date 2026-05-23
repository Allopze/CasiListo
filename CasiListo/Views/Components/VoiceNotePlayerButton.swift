import SwiftUI

/// Botón reutilizable para reproducir y detener notas de voz de forma interactiva con un waveform animado.
struct VoiceNotePlayerButton: View {
    let filename: String
    
    @State private var waveAnimation = false
    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0
    
    var body: some View {
        let isPlaying = VoiceNoteService.shared.currentlyPlayingFilename == filename
        
        Button {
            HapticFeedback.selection()
            if isPlaying {
                VoiceNoteService.shared.stopPlaying()
            } else {
                _ = VoiceNoteService.shared.startPlaying(filename: filename)
            }
        } label: {
            HStack(spacing: 8 * CGFloat(accessibilityTextSizeScale)) {
                // Waveform animado si está reproduciendo, o ícono de play si no
                if isPlaying {
                    HStack(spacing: 2) {
                        ForEach(0..<4) { index in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(.white)
                                .frame(width: 2, height: waveAnimation ? CGFloat.random(in: 6...18) : 10)
                                .animation(
                                    Animation.easeInOut(duration: 0.3)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(index) * 0.08),
                                    value: waveAnimation
                                )
                        }
                    }
                    .frame(width: 16, height: 20)
                    .onAppear {
                        waveAnimation = true
                    }
                    .onDisappear {
                        waveAnimation = false
                    }
                } else {
                    Image(systemName: "waveform")
                        .font(.system(size: 14 * CGFloat(accessibilityTextSizeScale), weight: .bold))
                        .foregroundStyle(Theme.accentYellow)
                }
            }
            .frame(width: 32 * CGFloat(accessibilityTextSizeScale), height: 32 * CGFloat(accessibilityTextSizeScale))
            .background(isPlaying ? Color.red.opacity(0.85) : Theme.accentYellow.opacity(0.12))
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPlaying ? "Detener nota de voz" : "Reproducir nota de voz")
    }
}
