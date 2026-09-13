import AVFoundation
import Foundation
import Observation
import os.log

enum VoiceNoteError: LocalizedError, Equatable {
    case permissionDenied
    case recordingUnavailable
    case sessionInterrupted
    case noSpace
    case fileMissing
    case recordingFailed
    case playbackFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "CasiListo necesita permiso de micrófono para grabar una nota de voz."
        case .recordingUnavailable: return "La grabación de audio no está disponible en este momento."
        case .sessionInterrupted: return "El audio fue interrumpido. Puedes intentarlo nuevamente."
        case .noSpace: return "No queda espacio suficiente para guardar la nota de voz."
        case .fileMissing: return "No se encontró el archivo de la nota de voz."
        case .recordingFailed: return "No se pudo iniciar la grabación."
        case .playbackFailed: return "No se pudo reproducir la nota de voz."
        }
    }
}

/// Servicio de grabación y reproducción. Las notas se graban como borradores y
/// solo se promueven al almacenamiento definitivo después del commit SwiftData.
@Observable
@MainActor
final class VoiceNoteService: NSObject, AVAudioPlayerDelegate {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "CasiListo", category: "VoiceNoteService")
    static let shared = VoiceNoteService()

    @ObservationIgnored private var audioRecorder: AVAudioRecorder?
    @ObservationIgnored private var audioPlayer: AVAudioPlayer?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    var isRecording = false
    var currentlyPlayingFilename: String?
    var lastError: VoiceNoteError?

    var isPlaying: Bool { currentlyPlayingFilename != nil }

    private override init() {
        super.init()
        observeAudioSession()
    }

    func isTemporary(filename: String) -> Bool {
        filename.hasPrefix("draft-")
    }

    func getAudioURL(for filename: String) -> URL? {
        if isTemporary(filename: filename) {
            return try? LocalFileStore.shared.temporaryVoiceNoteURL(named: filename)
        }
        return try? LocalFileStore.shared.finalVoiceNoteURL(named: filename)
    }

    // MARK: - Grabación

    func startRecording() -> Result<String, VoiceNoteError> {
        let session = AVAudioSession.sharedInstance()

        // Verificar permiso de micrófono antes de intentar grabar.
        switch AVAudioApplication.shared.recordPermission {
        case .denied:
            lastError = .permissionDenied
            return .failure(.permissionDenied)
        case .undetermined:
            // Si el permiso no se ha pedido aún, la grabación fallará cuando
            // iOS muestre el diálogo y el usuario decida. Se informa de
            // inmediato para que el caller solicite el permiso explícitamente.
            lastError = .permissionDenied
            return .failure(.permissionDenied)
        case .granted:
            break
        @unknown default:
            break
        }

        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)

            let filename = "draft-\(UUID().uuidString).m4a"
            let fileURL = try LocalFileStore.shared.temporaryVoiceNoteURL(named: filename)
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12_000.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
            ]
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.prepareToRecord()
            guard audioRecorder?.record(forDuration: 30) == true else {
                lastError = .recordingFailed
                return .failure(.recordingFailed)
            }
            isRecording = true
            lastError = nil
            return .success(filename)
        } catch {
            let mapped = map(error, fallback: .recordingFailed)
            lastError = mapped
            Self.logger.error("No se pudo iniciar la grabación: \(error.localizedDescription, privacy: .public)")
            return .failure(mapped)
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        deactivateSession()
    }

    func promoteTemporaryVoiceNoteIfNeeded(_ filename: String?) throws -> String? {
        guard let filename else { return nil }
        guard isTemporary(filename: filename) else { return filename }
        return try LocalFileStore.shared.promoteTemporaryVoiceNote(named: filename)
    }

    // MARK: - Reproducción

    func startPlaying(filename: String) -> Result<Void, VoiceNoteError> {
        stopPlaying()
        guard let fileURL = getAudioURL(for: filename), FileManager.default.fileExists(atPath: fileURL.path) else {
            lastError = .fileMissing
            return .failure(.fileMissing)
        }

        do {
            let session = AVAudioSession.sharedInstance()
            // Sin `duckOthers`, reproducir tres segundos de nota mataba la
            // música que la persona venía escuchando en el supermercado.
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
            audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            guard audioPlayer?.play() == true else {
                lastError = .playbackFailed
                return .failure(.playbackFailed)
            }
            currentlyPlayingFilename = filename
            lastError = nil
            return .success(())
        } catch {
            let mapped = map(error, fallback: .playbackFailed)
            lastError = mapped
            Self.logger.error("No se pudo reproducir audio: \(error.localizedDescription, privacy: .public)")
            return .failure(mapped)
        }
    }

    func stopPlaying() {
        audioPlayer?.stop()
        audioPlayer = nil
        currentlyPlayingFilename = nil
        deactivateSession()
    }

    func deleteVoiceNote(filename: String) {
        do {
            try LocalFileStore.shared.deleteVoiceNote(named: filename)
        } catch {
            Self.logger.error("No se pudo borrar la nota de voz: \(error.localizedDescription, privacy: .public)")
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.stopPlaying() }
    }

    private func observeAudioSession() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.stopRecording()
                self.stopPlaying()
                self.lastError = .sessionInterrupted
            }
        })
        observers.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            guard reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
            Task { @MainActor in
                self?.stopPlaying()
            }
        })
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func map(_ error: Error, fallback: VoiceNoteError) -> VoiceNoteError {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain, nsError.code == NSFileWriteOutOfSpaceError {
            return .noSpace
        }
        return fallback
    }
}
