import Foundation

protocol FileStore {
    func saveReceiptData(_ data: Data) throws -> String
    func receiptURL(named filename: String) throws -> URL
    func finalVoiceNoteURL(named filename: String) throws -> URL
    func temporaryVoiceNoteURL(named filename: String) throws -> URL
    func promoteTemporaryVoiceNote(named filename: String) throws -> String
    func deleteVoiceNote(named filename: String) throws
    func deleteReceipt(named filename: String) throws
    func cleanupUnreferencedFiles(voiceNoteFilenames: Set<String>, receiptFilenames: Set<String>) throws
    func resetAllFiles() throws
}

/// Almacenamiento local de fotos y audios. Las promociones se hacen dentro del
/// mismo volumen y las escrituras de boletas usan `.atomic`.
struct LocalFileStore: FileStore {
    static let shared = LocalFileStore()

    private let fileManager = FileManager.default

    func saveReceiptData(_ data: Data) throws -> String {
        let filename = "boleta-\(UUID().uuidString).jpg"
        try data.write(to: try receiptURL(named: filename), options: .atomic)
        return filename
    }

    func receiptURL(named filename: String) throws -> URL {
        try receiptsDirectory().appending(path: filename)
    }

    func finalVoiceNoteURL(named filename: String) throws -> URL {
        try voiceNotesDirectory().appending(path: filename)
    }

    func temporaryVoiceNoteURL(named filename: String) throws -> URL {
        try temporaryVoiceNotesDirectory().appending(path: filename)
    }

    func promoteTemporaryVoiceNote(named filename: String) throws -> String {
        let source = try temporaryVoiceNoteURL(named: filename)
        guard fileManager.fileExists(atPath: source.path) else {
            throw FileStoreError.fileMissing
        }
        let finalFilename = "voice-\(UUID().uuidString).m4a"
        let destination = try finalVoiceNoteURL(named: finalFilename)
        try fileManager.moveItem(at: source, to: destination)
        return finalFilename
    }

    func deleteVoiceNote(named filename: String) throws {
        let finalURL = try finalVoiceNoteURL(named: filename)
        let temporaryURL = try temporaryVoiceNoteURL(named: filename)
        for url in [finalURL, temporaryURL] where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    func deleteReceipt(named filename: String) throws {
        let url = try receiptURL(named: filename)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    func cleanupUnreferencedFiles(voiceNoteFilenames: Set<String>, receiptFilenames: Set<String>) throws {
        try removeUnreferencedFiles(in: voiceNotesDirectory(), keeping: voiceNoteFilenames)
        try removeUnreferencedFiles(in: temporaryVoiceNotesDirectory(), keeping: [])
        try removeUnreferencedFiles(in: receiptsDirectory(), keeping: receiptFilenames)
    }

    func resetAllFiles() throws {
        for directory in [try voiceNotesDirectory(), try receiptsDirectory()] {
            guard fileManager.fileExists(atPath: directory.path) else { continue }
            try fileManager.removeItem(at: directory)
        }
    }

    private func removeUnreferencedFiles(in directory: URL, keeping filenames: Set<String>) throws {
        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        for file in contents where !filenames.contains(file.lastPathComponent) {
            try fileManager.removeItem(at: file)
        }
    }

    private func receiptsDirectory() throws -> URL {
        let root = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = root.appending(path: "Receipts", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func voiceNotesDirectory() throws -> URL {
        let root = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = root.appending(path: "VoiceNotes", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func temporaryVoiceNotesDirectory() throws -> URL {
        let directory = try voiceNotesDirectory().appending(path: ".temporary", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

enum FileStoreError: LocalizedError {
    case fileMissing

    var errorDescription: String? {
        switch self {
        case .fileMissing:
            return "El archivo ya no está disponible en este dispositivo."
        }
    }
}
