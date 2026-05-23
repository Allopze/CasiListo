import Foundation
import AVFoundation

/// Servicio encargado de la grabación y reproducción de notas de voz asociadas a los productos.
final class VoiceNoteService: NSObject, AVAudioPlayerDelegate {
    static let shared = VoiceNoteService()
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var playCompletion: (() -> Void)?
    
    var isRecording: Bool {
        audioRecorder?.isRecording ?? false
    }
    
    var isPlaying: Bool {
        audioPlayer?.isPlaying ?? false
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
            return audioRecorder?.record(forDuration: 30.0) ?? false // Límite de 30 segundos
        } catch {
            print("Error al configurar la grabación de audio: \(error)")
            return false
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        
        // Desactivar la sesión de audio de forma segura
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    // MARK: - Reproducción
    
    func startPlaying(filename: String, onFinished: @escaping () -> Void) -> Bool {
        stopPlaying()
        
        let fileURL = getAudioURL(for: filename)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return false }
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
            
            self.playCompletion = onFinished
            audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            return audioPlayer?.play() ?? false
        } catch {
            print("Error al reproducir audio: \(error)")
            return false
        }
    }
    
    func stopPlaying() {
        audioPlayer?.stop()
        audioPlayer = nil
        playCompletion?()
        playCompletion = nil
        
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    func deleteVoiceNote(filename: String) {
        let fileURL = getAudioURL(for: filename)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
    
    // MARK: - AVAudioPlayerDelegate
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stopPlaying()
    }
}
