import Foundation
import AVFoundation
import Observation

/// Servicio encargado de la grabación y reproducción de notas de voz asociadas a los productos.
@Observable
@MainActor
final class VoiceNoteService: NSObject, AVAudioPlayerDelegate {
    static let shared = VoiceNoteService()
    
    @ObservationIgnored private var audioRecorder: AVAudioRecorder?
    @ObservationIgnored private var audioPlayer: AVAudioPlayer?
    
    var isRecording: Bool = false
    var currentlyPlayingFilename: String?
    
    var isPlaying: Bool {
        currentlyPlayingFilename != nil
    }
    
    private override init() {
        super.init()
    }
    
    /// Obtiene la ruta del directorio de documentos de la aplicación.
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    /// Crea el subdirectorio para notas de voz si no existe.
    private var voiceNotesDirectory: URL {
        let url = documentsDirectory.appendingPathComponent("VoiceNotes", isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }
    
    /// Devuelve la URL local completa de una nota de voz a partir de su nombre de archivo.
    func getAudioURL(for filename: String) -> URL {
        voiceNotesDirectory.appendingPathComponent(filename)
    }
    
    // MARK: - Grabación
    
    func startRecording(filename: String) -> Bool {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Configurar sesión de audio para grabación y reproducción
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
            
            let fileURL = getAudioURL(for: filename)
            
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.prepareToRecord()
            let success = audioRecorder?.record(forDuration: 30.0) ?? false // Límite de 30 segundos
            if success {
                isRecording = true
            }
            return success
        } catch {
            print("Error al configurar la grabación de audio: \(error)")
            return false
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        
        // Desactivar la sesión de audio de forma segura
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    // MARK: - Reproducción
    
    func startPlaying(filename: String) -> Bool {
        stopPlaying()
        
        let fileURL = getAudioURL(for: filename)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return false }
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
            
            audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            let success = audioPlayer?.play() ?? false
            if success {
                currentlyPlayingFilename = filename
            }
            return success
        } catch {
            print("Error al reproducir audio: \(error)")
            return false
        }
    }
    
    func stopPlaying() {
        audioPlayer?.stop()
        audioPlayer = nil
        currentlyPlayingFilename = nil
        
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    func deleteVoiceNote(filename: String) {
        let fileURL = getAudioURL(for: filename)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
    
    // MARK: - AVAudioPlayerDelegate
    
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            VoiceNoteService.shared.stopPlaying()
        }
    }
}
