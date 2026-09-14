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
    /// La persona detuvo o volvió a iniciar antes de que la sesión de audio
    /// terminara de activarse. No es un fallo que mostrar: sin mensaje.
    case superseded

    var errorDescription: String? {
        switch self {
        case .superseded: return nil
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
    /// Última operación encolada sobre `AVAudioSession`. Cada nueva operación
    /// espera a la anterior antes de tocar la sesión, así activar y desactivar
    /// llegan al sistema en el orden en que se pidieron aunque corran fuera
    /// del hilo principal.
    @ObservationIgnored private var lastSessionOperation: Task<Void, any Error>?
    /// Se incrementa en cada inicio/detención. Sirve para descartar una
    /// activación que terminó después de que la persona ya detuvo o volvió
    /// a iniciar, y no dejar un grabador o reproductor huérfano en marcha.
    @ObservationIgnored private var sessionGeneration = 0

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

    func startRecording() async -> Result<String, VoiceNoteError> {
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

        sessionGeneration += 1
        let generation = sessionGeneration

        do {
            try await activateSession(category: .playAndRecord, options: [.defaultToSpeaker])
            // Si mientras se activaba la sesión la persona detuvo o volvió a
            // iniciar, esta llamada ya no manda: la más reciente se encarga.
            guard generation == sessionGeneration else { return .failure(.superseded) }

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
        sessionGeneration += 1
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

    func startPlaying(filename: String) async -> Result<Void, VoiceNoteError> {
        stopPlaying()
        guard let fileURL = getAudioURL(for: filename), FileManager.default.fileExists(atPath: fileURL.path) else {
            lastError = .fileMissing
            return .failure(.fileMissing)
        }

        sessionGeneration += 1
        let generation = sessionGeneration

        do {
            // Sin `duckOthers`, reproducir tres segundos de nota mataba la
            // música que la persona venía escuchando en el supermercado.
            try await activateSession(category: .playback, options: [.duckOthers])
            guard generation == sessionGeneration else { return .failure(.superseded) }
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
        sessionGeneration += 1
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

    // MARK: - Sesión de audio

    /// `setActive` bloquea hasta que el sistema reconfigura el audio (con
    /// audífonos Bluetooth, cientos de ms): Xcode lo marca como riesgo de
    /// hang si se llama en el hilo principal. La API asíncrona nativa
    /// (`activate(options:)`) es iOS 27+, y el piso es iOS 26, así que la
    /// llamada síncrona se saca del main thread en una cola serial propia.
    private func activateSession(category: AVAudioSession.Category, options: AVAudioSession.CategoryOptions) async throws {
        try await performOnAudioSession {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(category, mode: .default, options: options)
            try session.setActive(true)
        }.value
    }

    private func deactivateSession() {
        // Sin `await`: quien detiene no necesita esperar a que el sistema
        // libere el audio. La cadena de operaciones garantiza que una
        // activación pedida justo después no se adelante a esta desactivación.
        performOnAudioSession {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    @discardableResult
    private func performOnAudioSession(_ operation: @escaping @Sendable () throws -> Void) -> Task<Void, any Error> {
        let previous = lastSessionOperation
        let task = Task.detached(priority: .userInitiated) {
            // El resultado anterior se ignora a propósito: una desactivación
            // fallida no debe impedir la siguiente activación.
            _ = await previous?.result
            try operation()
        }
        lastSessionOperation = task
        return task
    }

    private func map(_ error: Error, fallback: VoiceNoteError) -> VoiceNoteError {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain, nsError.code == NSFileWriteOutOfSpaceError {
            return .noSpace
        }
        return fallback
    }
}
