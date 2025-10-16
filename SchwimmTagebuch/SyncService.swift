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
        let zipURL = directory.appendingPathComponent("SchwimmTagebuch-\(timestamp).zip")
        if FileManager.default.fileExists(atPath: zipURL.path) {
            try FileManager.default.removeItem(at: zipURL)
        }

        let entries: [SimpleZip.Entry] = [
            .init(fileName: "training.csv", data: CSVBuilder.trainingsCSV(sessions).data(using: .utf8) ?? Data()),
            .init(fileName: "wettkaempfe.csv", data: CSVBuilder.wettkampfCSV(competitions).data(using: .utf8) ?? Data()),
            .init(fileName: "export.json", data: JSONBuilder.exportJSON(sessions: sessions, competitions: competitions).data(using: .utf8) ?? Data())
        ]

        try SimpleZip.write(entries: entries, to: zipURL)
        return zipURL
    }

    private static let timestampFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd-HHmm"
        return df
    }()
}

private enum SimpleZip {
    struct Entry {
        let fileName: String
        let data: Data
        let date: Date

        init(fileName: String, data: Data, date: Date = Date()) {
            self.fileName = fileName
            self.data = data
            self.date = date
        }
    }

    static func write(entries: [Entry], to url: URL) throws {
        var archiveData = Data()
        var centralDirectory = Data()
        var offset: UInt32 = 0

        for entry in entries {
            let fileNameData = Data(entry.fileName.utf8)
            let (dosTime, dosDate) = dosDateTime(from: entry.date)
            let crc = crc32(entry.data)
            let size = UInt32(entry.data.count)

            var localHeader = Data()
            localHeader.append(uint32: 0x04034B50)
            localHeader.append(uint16: 20)
            localHeader.append(uint16: 0)
            localHeader.append(uint16: 0)
            localHeader.append(uint16: dosTime)
            localHeader.append(uint16: dosDate)
            localHeader.append(uint32: crc)
            localHeader.append(uint32: size)
            localHeader.append(uint32: size)
            localHeader.append(uint16: UInt16(fileNameData.count))
            localHeader.append(uint16: 0)
            localHeader.append(fileNameData)

            archiveData.append(localHeader)
            archiveData.append(entry.data)

            var central = Data()
            central.append(uint32: 0x02014B50)
            central.append(uint16: 20)
            central.append(uint16: 20)
            central.append(uint16: 0)
            central.append(uint16: 0)
            central.append(uint16: dosTime)
            central.append(uint16: dosDate)
            central.append(uint32: crc)
            central.append(uint32: size)
            central.append(uint32: size)
            central.append(uint16: UInt16(fileNameData.count))
            central.append(uint16: 0)
            central.append(uint16: 0)
            central.append(uint16: 0)
            central.append(uint16: 0)
            central.append(uint32: 0)
            central.append(uint32: offset)
            central.append(fileNameData)

            centralDirectory.append(central)
            offset = UInt32(archiveData.count)
        }

        let centralDirectoryOffset = UInt32(archiveData.count)
        archiveData.append(centralDirectory)
        let centralDirectorySize = UInt32(centralDirectory.count)

        var end = Data()
        end.append(uint32: 0x06054B50)
        end.append(uint16: 0)
        end.append(uint16: 0)
        end.append(uint16: UInt16(entries.count))
        end.append(uint16: UInt16(entries.count))
        end.append(uint32: centralDirectorySize)
        end.append(uint32: centralDirectoryOffset)
        end.append(uint16: 0)

        archiveData.append(end)

        try archiveData.write(to: url, options: .atomic)
    }

    private static func dosDateTime(from date: Date) -> (UInt16, UInt16) {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: TimeZone.current, from: date)
        let year = UInt16(max(min((components.year ?? 1980) - 1980, 127), 0))
        let month = UInt16(max(min(components.month ?? 1, 12), 1))
        let day = UInt16(max(min(components.day ?? 1, 31), 1))
        let hour = UInt16(max(min(components.hour ?? 0, 23), 0))
        let minute = UInt16(max(min(components.minute ?? 0, 59), 0))
        let second = UInt16(max(min(components.second ?? 0, 59), 0))

        let dosDate = (year << 9) | (month << 5) | day
        let dosTime = (hour << 11) | (minute << 5) | (second / 2)
        return (dosTime, dosDate)
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            let idx = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = (crc >> 8) ^ crcTable[idx]
        }
        return crc ^ 0xFFFF_FFFF
    }

    private static let crcTable: [UInt32] = {
        (0..<256).map { i -> UInt32 in
            var c = UInt32(i)
            for _ in 0..<8 {
                if c & 1 == 1 {
                    c = 0xEDB88320 ^ (c >> 1)
                } else {
                    c >>= 1
                }
            }
            return c
        }
    }()
}

private extension Data {
    mutating func append(uint16 value: UInt16) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }

    mutating func append(uint32 value: UInt32) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }
}
