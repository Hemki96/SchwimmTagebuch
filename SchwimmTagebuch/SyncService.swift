import Foundation

enum AutoBackupError: LocalizedError {
    case noData

    var errorDescription: String? {
        switch self {
        case .noData: return "Es gibt keine Trainings- oder Wettkampfdaten zum Sichern."
        }
    }
}

enum AutoBackupService {
    static func performBackup(sessions: [TrainingSession], competitions: [Competition], format: ExportFormat) throws -> URL {
        guard !sessions.isEmpty || !competitions.isEmpty else { throw AutoBackupError.noData }
        let fileManager = FileManager.default
        let directory = try backupDirectory()
        let timestamp = timestampFormatter.string(from: Date())

        switch format {
        case .json:
            let json = JSONBuilder.exportJSON(sessions: sessions, competitions: competitions)
            let url = directory.appendingPathComponent("SchwimmTagebuch-\(timestamp).json")
            try json.data(using: .utf8)?.write(to: url, options: .atomic)
            return url
        case .csv:
            let csvTrain = CSVBuilder.trainingsCSV(sessions)
            let url = directory.appendingPathComponent("SchwimmTagebuch-Training-\(timestamp).csv")
            try csvTrain.data(using: .utf8)?.write(to: url, options: .atomic)
            return url
        case .zipBundle:
            return try createBundleZip(sessions: sessions, competitions: competitions, directory: directory, timestamp: timestamp)
        }
    }

    private static func backupDirectory() throws -> URL {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let backupDir = docs.appendingPathComponent("SchwimmTagebuchBackups", isDirectory: true)
        if !fm.fileExists(atPath: backupDir.path) {
            try fm.createDirectory(at: backupDir, withIntermediateDirectories: true)
        }
        return backupDir
    }

    private static func createBundleZip(sessions: [TrainingSession], competitions: [Competition], directory: URL, timestamp: String) throws -> URL {
        let fm = FileManager.default
        let workingDir = directory.appendingPathComponent("Bundle-\(timestamp)", isDirectory: true)
        if fm.fileExists(atPath: workingDir.path) {
            try fm.removeItem(at: workingDir)
        }
        try fm.createDirectory(at: workingDir, withIntermediateDirectories: true)

        let trainURL = workingDir.appendingPathComponent("training.csv")
        let compURL = workingDir.appendingPathComponent("wettkaempfe.csv")
        let jsonURL = workingDir.appendingPathComponent("export.json")

        try CSVBuilder.trainingsCSV(sessions).data(using: .utf8)?.write(to: trainURL, options: .atomic)
        try CSVBuilder.wettkampfCSV(competitions).data(using: .utf8)?.write(to: compURL, options: .atomic)
        try JSONBuilder.exportJSON(sessions: sessions, competitions: competitions).data(using: .utf8)?.write(to: jsonURL, options: .atomic)

        let zipURL = directory.appendingPathComponent("SchwimmTagebuch-\(timestamp).zip")
        if fm.fileExists(atPath: zipURL.path) {
            try fm.removeItem(at: zipURL)
        }
        try fm.zipItem(at: workingDir, to: zipURL, shouldKeepParent: false, compressionMethod: .automatic)
        try fm.removeItem(at: workingDir)
        return zipURL
    }

    private static let timestampFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd-HHmm"
        return df
    }()
}
