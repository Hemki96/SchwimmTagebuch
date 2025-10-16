import Foundation

enum AutoBackupError: LocalizedError {
    case noData

    var errorDescription: String? {
        switch self {
        case .noData: return "Es gibt keine Trainings- oder Wettkampfdaten zum Sichern."
        }
    }
}

struct AutoBackupConfiguration {
    var fileManager: FileManager
    var dateProvider: () -> Date
    var directoryProvider: (FileManager) throws -> URL

    init(
        fileManager: FileManager = .default,
        dateProvider: @escaping () -> Date = Date.init,
        directoryProvider: @escaping (FileManager) throws -> URL = AutoBackupConfiguration.defaultDirectoryProvider
    ) {
        self.fileManager = fileManager
        self.dateProvider = dateProvider
        self.directoryProvider = directoryProvider
    }

    private static func defaultDirectoryProvider(fileManager: FileManager) throws -> URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        let backupDir = docs.appendingPathComponent("SchwimmTagebuchBackups", isDirectory: true)
        if !fileManager.fileExists(atPath: backupDir.path) {
            try fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)
        }
        return backupDir
    }

    static var `default`: AutoBackupConfiguration { AutoBackupConfiguration() }
}

enum AutoBackupService {
    static func performBackup(
        sessions: [TrainingSession],
        competitions: [Competition],
        format: ExportFormat,
        configuration: AutoBackupConfiguration = .default
    ) throws -> URL {
        guard !sessions.isEmpty || !competitions.isEmpty else { throw AutoBackupError.noData }
        let fileManager = configuration.fileManager
        let directory = try configuration.directoryProvider(fileManager)
        let timestamp = timestampFormatter.string(from: configuration.dateProvider())

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
            return try createBundleZip(
                sessions: sessions,
                competitions: competitions,
                directory: directory,
                timestamp: timestamp,
                fileManager: fileManager
            )
        }
    }

    private static func createBundleZip(
        sessions: [TrainingSession],
        competitions: [Competition],
        directory: URL,
        timestamp: String,
        fileManager: FileManager
    ) throws -> URL {
        let zipURL = directory.appendingPathComponent("SchwimmTagebuch-\(timestamp).zip")
        if fileManager.fileExists(atPath: zipURL.path) {
            try fileManager.removeItem(at: zipURL)
        }

        let entries: [ZipArchive.Entry] = [
            .init(fileName: "training.csv", data: CSVBuilder.trainingsCSV(sessions).data(using: .utf8) ?? Data()),
            .init(fileName: "wettkaempfe.csv", data: CSVBuilder.wettkampfCSV(competitions).data(using: .utf8) ?? Data()),
            .init(fileName: "export.json", data: JSONBuilder.exportJSON(sessions: sessions, competitions: competitions).data(using: .utf8) ?? Data())
        ]

        try ZipArchive.write(entries: entries, to: zipURL)
        return zipURL
    }

    private static let timestampFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd-HHmm"
        return df
    }()
}
