import Foundation

enum CloudSyncError: LocalizedError {
    case containerUnavailable

    var errorDescription: String? {
        switch self {
        case .containerUnavailable:
            return "iCloud Drive ist nicht verfügbar. Melde dich an oder aktiviere iCloud Drive."
        }
    }
}

enum CloudSyncService {
    static func synchronize(localBackup url: URL, fileManager: FileManager = .default) throws -> URL {
        guard let containerURL = fileManager.url(forUbiquityContainerIdentifier: nil) else {
            throw CloudSyncError.containerUnavailable
        }
        let documentsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)
        let targetDirectory = documentsURL.appendingPathComponent("SchwimmTagebuchBackups", isDirectory: true)
        if !fileManager.fileExists(atPath: targetDirectory.path) {
            try fileManager.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
        }
        let targetURL = targetDirectory.appendingPathComponent(url.lastPathComponent)
        if fileManager.fileExists(atPath: targetURL.path) {
            try fileManager.removeItem(at: targetURL)
        }
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.copyItem(at: url, to: targetURL)
        }
        return targetURL
    }
}
