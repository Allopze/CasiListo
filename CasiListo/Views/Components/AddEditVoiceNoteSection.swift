import SwiftUI
import AVFoundation

/// Sección para grabar y reproducir notas de voz dentro del formulario de edición.
struct AddEditVoiceNoteSection: View {
    @Binding var voiceNoteFilename: String?
    
    @State private var isRecording = false
    @State private var recordingPulse = false
    @State private var recordingDuration = 0
    @State private var recordingDurationTask: Task<Void, Never>? = nil

    @AppStorage("accessibilityTextSizeScale") private var accessibilityTextSizeScale = 1.0

    var body: some View {
        Section {
            HStack(spacing: 16) {
                if isRecording {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .opacity(recordingPulse ? 1.0 : 0.2)
                            .animation(Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: recordingPulse)
                            .onAppear { recordingPulse = true }
                            .onDisappear { recordingPulse = false }
                        
                        Text("Grabando... \(recordingDuration)s")
                            .font(Theme.bodyBoldFont(scale: accessibilityTextSizeScale))
                            .foregroundStyle(.red)
                    }
                    Spacer()
                    Button { stopRecording() } label: {
                        Text("Detener")
                            .font(Theme.captionFont(scale: accessibilityTextSizeScale))
                            .bold()
                            .foregroundStyle(.white)
                            .frame(minWidth: Theme.minimumTouchTarget, minHeight: Theme.minimumTouchTarget)
                            .padding(.horizontal, 12)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    
                } else if let filename = voiceNoteFilename {
                    Image(systemName: "waveform")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.accentYellow)
                    Text("Nota de voz")
                        .font(Theme.bodyFont(scale: accessibilityTextSizeScale))
                        .foregroundStyle(Color.appTextPrimary)
                    Spacer()
                    VoiceNotePlayerButton(filename: filename)
                    Button {
                        HapticFeedback.impact()
                        deleteVoiceNote()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                            .frame(width: Theme.minimumTouchTarget, height: Theme.minimumTouchTarget)
                            .background(Color.red.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                } else {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.appTextSecondary)
                    Text("Grabar nota de voz")
                        .font(Theme.bodyFont(scale: accessibilityTextSizeScale))
                        .foregroundStyle(Color.appTextSecondary)
                    Spacer()
                    Button { startRecording() } label: {
                        Image(systemName: "mic.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Theme.accentYellow)
                            .frame(width: Theme.minimumTouchTarget, height: Theme.minimumTouchTarget)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listRowInsets(.init(top: 8, leading: 12, bottom: 8, trailing: 12))
        } header: {
            Label("Nota de Voz", systemImage: "mic.fill")
        }
        .onDisappear {
            stopRecordingIfNeeded()
        }
    }

    @MainActor
    private func startRecording() {
        let filename = "voice_\(UUID().uuidString).m4a"
        if #available(iOS 17.0, *) {
            Task {
                let granted = await AVAudioApplication.requestRecordPermission()
                if granted {
                    HapticFeedback.selection()
                    let success = VoiceNoteService.shared.startRecording(filename: filename)
                    if success {
                        self.voiceNoteFilename = filename
                        self.isRecording = true
                        self.recordingDuration = 0
                        self.startRecordingDurationTask()
                    }
                }
            }
        }
    }
    
    @MainActor
    private func stopRecording() {
        HapticFeedback.success()
        recordingDurationTask?.cancel()
        recordingDurationTask = nil
        VoiceNoteService.shared.stopRecording()
        isRecording = false
    }

    @MainActor
    private func stopRecordingIfNeeded() {
        if isRecording {
            stopRecording()
        } else {
            recordingDurationTask?.cancel()
            recordingDurationTask = nil
        }
    }

    @MainActor
    private func startRecordingDurationTask() {
        recordingDurationTask?.cancel()
        recordingDurationTask = Task { @MainActor in
            while !Task.isCancelled && isRecording {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                recordingDuration += 1

                if recordingDuration >= 30 {
                    stopRecording()
                    return
                }
            }
        }
    }
    
    private func deleteVoiceNote() {
        if let filename = voiceNoteFilename {
            VoiceNoteService.shared.deleteVoiceNote(filename: filename)
            voiceNoteFilename = nil
        }
    }
}
