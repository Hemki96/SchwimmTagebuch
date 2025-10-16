import Foundation

enum ZipArchive {
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

    static func fileNames(at url: URL) throws -> [String] {
        let data = try Data(contentsOf: url)
        return try fileNames(in: data)
    }

    static func fileNames(in data: Data) throws -> [String] {
        var names: [String] = []
        var offset = 0

        while offset + 30 <= data.count {
            let signature = data.readUInt32(at: offset)
            guard signature == 0x04034B50 else { break }

            let nameLength = Int(data.readUInt16(at: offset + 26))
            let extraLength = Int(data.readUInt16(at: offset + 28))
            let compressedSize = Int(data.readUInt32(at: offset + 18))

            let nameStart = offset + 30
            let nameEnd = nameStart + nameLength
            guard nameEnd <= data.count else { break }

            let nameData = data.subdata(in: nameStart..<nameEnd)
            if let name = String(data: nameData, encoding: .utf8) {
                names.append(name)
            }

            let dataStart = nameEnd + extraLength
            offset = dataStart + compressedSize
        }

        return names
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

    func readUInt16(at offset: Int) -> UInt16 {
        let range = offset..<(offset + 2)
        return self[range].withUnsafeBytes { UInt16(littleEndian: $0.load(as: UInt16.self)) }
    }

    func readUInt32(at offset: Int) -> UInt32 {
        let range = offset..<(offset + 4)
        return self[range].withUnsafeBytes { UInt32(littleEndian: $0.load(as: UInt32.self)) }
    }
}
