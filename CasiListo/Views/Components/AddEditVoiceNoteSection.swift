import SwiftUI
import AVFoundation
import UIKit

/// Sección para grabar y reproducir notas de voz dentro del formulario de edición.
struct AddEditVoiceNoteSection: View {
    @Binding var voiceNoteFilename: String?
    var onRecorded: (String) -> Void = { _ in }
    var onRemoved: (String) -> Void = { _ in }
    
    @State private var isRecording = false
    @State private var recordingPulse = false
    @State private var recordingDuration = 0
    @State private var recordingDurationTask: Task<Void, Never>? = nil
    @State private var errorMessage: String?
    @Environment(VoiceNoteService.self) private var voiceNoteService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var shouldFocusRecordButton: Bool


    var body: some View {
        Section {
            HStack(spacing: 16) {
                if isRecording {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .opacity(recordingPulse ? 1.0 : 0.2)
                            .animation(reduceMotion ? nil : Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: recordingPulse)
                            .onAppear { recordingPulse = !reduceMotion }
                            .onDisappear { recordingPulse = false }
                        
                        Text("Grabando... \(recordingDuration)s")
                            .font(Theme.bodyBoldDynamic)
                            .foregroundStyle(.red)
                    }
                    Spacer()
                    Button { stopRecording() } label: {
                        Text("Detener")
                            .font(Theme.captionDynamic)
                            .bold()
                            .foregroundStyle(.white)
                            .frame(minWidth: Theme.minimumTouchTarget, minHeight: Theme.minimumTouchTarget)
                            .padding(.horizontal, 12)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Detener grabación de nota de voz")
                    
                } else if let filename = voiceNoteFilename {
                    Image(systemName: "waveform")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.accentYellow)
                    Text("Nota de voz")
                        .font(Theme.bodyDynamic)
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
                    .accessibilityLabel("Eliminar nota de voz")
                    
                } else {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.appTextSecondary)
                    Text("Grabar nota de voz")
                        .font(Theme.bodyDynamic)
                        .foregroundStyle(Color.appTextSecondary)
                    Spacer()
                    Button { startRecording() } label: {
                        Image(systemName: "mic.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Theme.accentYellow)
                            .frame(width: Theme.minimumTouchTarget, height: Theme.minimumTouchTarget)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Grabar nota de voz")
                    .accessibilityFocused($shouldFocusRecordButton)
                }
            }
            .listRowInsets(.init(top: 8, leading: 12, bottom: 8, trailing: 12))
        } header: {
            Label("Nota de Voz", systemImage: "mic.fill")
        }
        .onDisappear {
            stopRecordingIfNeeded()
        }
        .onChange(of: voiceNoteService.isRecording) { _, serviceIsRecording in
            guard isRecording, !serviceIsRecording else { return }
            recordingDurationTask?.cancel()
            recordingDurationTask = nil
            isRecording = false
            if let lastError = voiceNoteService.lastError {
                errorMessage = lastError.errorDescription
            }
        }
        .alert(
            "No se pudo usar el micrófono",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("Intentar nuevamente") { startRecording() }
            Button("Ir a Ajustes") { openAppSettings() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Inténtalo nuevamente.")
        }
        .onChange(of: errorMessage) { oldValue, newValue in
            if oldValue != nil, newValue == nil {
                shouldFocusRecordButton = true
            }
        }
    }

    @MainActor
    private func startRecording() {
        if #available(iOS 17.0, *) {
            Task {
                let granted = await AVAudioApplication.requestRecordPermission()
                guard granted else {
                    errorMessage = VoiceNoteError.permissionDenied.errorDescription
                    return
                }
                switch voiceNoteService.startRecording() {
                case .success(let filename):
                    HapticFeedback.selection()
                    self.voiceNoteFilename = filename
                    self.onRecorded(filename)
                    self.isRecording = true
                    self.recordingDuration = 0
                    self.startRecordingDurationTask()
                case .failure(let error):
                    errorMessage = error.errorDescription
                }
            }
        }
    }
    
    @MainActor
    private func stopRecording() {
        HapticFeedback.selection()
        recordingDurationTask?.cancel()
        recordingDurationTask = nil
        voiceNoteService.stopRecording()
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
            onRemoved(filename)
            voiceNoteFilename = nil
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
}
