import Foundation
import XCTest
@testable import SchwimmTagebuch

/// Klassische `XCTestCase`-basierte Tests, damit das Projekt auch ohne das
/// neue Swift Testing Framework gebaut und ausgeführt werden kann.
final class SchwimmTagebuchTests: XCTestCase {

    func testCSVExportErzeugtKorrekteZeilen() {
        // Vorbereiten einer Trainings-Session inklusive eines Wettkampfs
        let session = TrainingSession(
            datum: Date(timeIntervalSince1970: 0),
            meter: 2500,
            dauerSek: 3600,
            borgWert: 4,
            notizen: "Langer Satz",
            ort: .becken,
            gefuehl: "Gute Wasserlage"
        )
        let comp = Competition(
            datum: Date(timeIntervalSince1970: 86_400),
            name: "Stadtmeisterschaft",
            ort: "Berlin",
            bahn: .scm25
        )
        let race = RaceResult(lage: .freistil, distanz: 100, zeitSek: 62)
        race.platz = 2
        race.istPB = true
        comp.results.append(race)

        // Export erzeugen
        let trainingCSV = CSVBuilder.trainingsCSV([session])
        let competitionCSV = CSVBuilder.wettkampfCSV([comp])

        // Erste Zeile sind die Header, zweite Zeile enthält unsere Werte
        let trainingZeilen = trainingCSV.split(separator: "\n", omittingEmptySubsequences: false)
        XCTAssertEqual(trainingZeilen.count, 2)
        XCTAssertEqual(trainingZeilen[1], "1970-01-01,2500,60,4,Becken,Gute Wasserlage,Langer Satz")

        let competitionZeilen = competitionCSV.split(separator: "\n", omittingEmptySubsequences: false)
        XCTAssertEqual(competitionZeilen.count, 2)
        XCTAssertEqual(competitionZeilen[1], "1970-01-02,Stadtmeisterschaft,Berlin,25 m,Freistil,100,62,2,true")
    }

    func testJSONExportEnthaeltSetsUndErgebnisse() {
        let session = TrainingSession(
            datum: Date(timeIntervalSince1970: 0),
            meter: 3000,
            dauerSek: 4500,
            borgWert: 6,
            notizen: "Mit Technikanteil",
            ort: .freiwasser,
            gefuehl: "Solide"
        )
        let set = WorkoutSet(
            titel: "8×50 Technik",
            wiederholungen: 8,
            distanzProWdh: 50,
            intervallSek: 75,
            equipment: ["Pullbuoy"],
            kommentar: "Drills"
        )
        set.laps = [
            SetLap(index: 0, splitSek: 42),
            SetLap(index: 1, splitSek: 41)
        ]
        session.sets.append(set)

        let comp = Competition(
            datum: Date(timeIntervalSince1970: 172_800),
            name: "Sommercup",
            ort: "Hamburg",
            bahn: .lcm50
        )
        let race = RaceResult(lage: .lagen, distanz: 200, zeitSek: 150)
        comp.results.append(race)

        let jsonString = JSONBuilder.exportJSON(sessions: [session], competitions: [comp])

        // JSON analysieren und auf die relevanten Felder prüfen
        struct Root: Decodable {
            struct Training: Decodable {
                let date: String
                let totalMeters: Int
                let sets: [TrainingSet]
            }
            struct TrainingSet: Decodable {
                let title: String
                let laps: [Int]
            }
            struct Competition: Decodable {
                let name: String
                let results: [Result]
            }
            struct Result: Decodable {
                let stroke: String
                let distance: Int
            }
            let trainings: [Training]
            let competitions: [Competition]
        }

        let data = try! Data(jsonString.utf8)
        let decoded = try! JSONDecoder().decode(Root.self, from: data)

        XCTAssertEqual(decoded.trainings.count, 1)
        XCTAssertEqual(decoded.trainings[0].date, "1970-01-01")
        XCTAssertEqual(decoded.trainings[0].totalMeters, 3000)
        XCTAssertEqual(decoded.trainings[0].sets.first?.title, "8×50 Technik")
        XCTAssertEqual(decoded.trainings[0].sets.first?.laps, [42, 41])

        XCTAssertEqual(decoded.competitions.count, 1)
        XCTAssertEqual(decoded.competitions[0].name, "Sommercup")
        XCTAssertEqual(decoded.competitions[0].results.first?.stroke, "Lagen")
        XCTAssertEqual(decoded.competitions[0].results.first?.distance, 200)
    }

    func testExportDataFactoryAggregiertEquipmentUndTechnik() {
        let session = TrainingSession(
            datum: Date(timeIntervalSince1970: 0),
            meter: 2000,
            dauerSek: 2700,
            borgWert: 5,
            notizen: nil,
            ort: .becken,
            gefuehl: "Solide"
        )

        let set1 = WorkoutSet(
            titel: "Warm-Up",
            wiederholungen: 4,
            distanzProWdh: 100,
            intervallSek: 120,
            equipment: [TrainingEquipment.pullbuoy.rawValue, "extra"],
            technikSchwerpunkte: [TechniqueFocus.breathing.rawValue],
            kommentar: nil
        )
        set1.laps = [SetLap(index: 0, splitSek: 90)]

        let set2 = WorkoutSet(
            titel: "Main",
            wiederholungen: 5,
            distanzProWdh: 200,
            intervallSek: 180,
            equipment: [TrainingEquipment.resistanceBand.rawValue, TrainingEquipment.pullbuoy.rawValue],
            technikSchwerpunkte: [TechniqueFocus.paceControl.rawValue],
            kommentar: nil
        )

        session.sets.append(contentsOf: [set1, set2])

        let exports = ExportDataFactory.sessions([session])
        XCTAssertEqual(exports.count, 1)

        guard let export = exports.first else {
            return XCTFail("Exportdaten fehlen")
        }
        XCTAssertEqual(export.totalMinutes, 45)
        XCTAssertEqual(export.locationTitle, "Becken")
        XCTAssertEqual(export.equipmentSummary, ["Band", "Pullbuoy"])
        XCTAssertEqual(export.techniqueSummary, ["Atmung", "Pace"])

        guard let firstSet = export.sets.first else {
            return XCTFail("Set Export fehlt")
        }
        XCTAssertEqual(firstSet.equipment, ["Pullbuoy", "extra"])
        XCTAssertEqual(firstSet.technique, ["Atmung"])
        XCTAssertEqual(firstSet.laps, [90])
    }

    func testCSVBuilderEscapedSonderzeichen() {
        let session = TrainingSession(
            datum: Date(timeIntervalSince1970: 0),
            meter: 500,
            dauerSek: 480,
            borgWert: 4,
            notizen: "Anmerkung, \"Test\"",
            ort: .becken,
            gefuehl: "Sehr \"gut\""
        )

        let csv = CSVBuilder.trainingsCSV([session])
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false)
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(
            lines[1],
            "1970-01-01,500,8,4,Becken,\"Sehr \"\"gut\"\"\",\"Anmerkung, \"\"Test\"\"\",,"
        )
    }

    func testAutoBackupServiceWirftFehlerOhneDaten() {
        XCTAssertThrowsError(try AutoBackupService.performBackup(
            sessions: [],
            competitions: [],
            format: .json
        )) { error in
            XCTAssertTrue(error is AutoBackupError)
        }
    }

    func testAutoBackupServiceSchreibtInKonfiguriertesVerzeichnis() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let config = AutoBackupConfiguration(
            fileManager: .default,
            dateProvider: { Date(timeIntervalSince1970: 0) },
            directoryProvider: { _ in tempDir }
        )

        let session = TrainingSession(
            datum: Date(timeIntervalSince1970: 0),
            meter: 1500,
            dauerSek: 1800,
            borgWert: 6
        )

        let url = try AutoBackupService.performBackup(
            sessions: [session],
            competitions: [],
            format: .json,
            configuration: config
        )

        XCTAssertTrue(url.path.hasPrefix(tempDir.path))
        let data = try Data(contentsOf: url)
        XCTAssertFalse(data.isEmpty)
    }

    func testAutoBackupServiceZipBundleEnthaeltAlleDateien() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let config = AutoBackupConfiguration(
            fileManager: .default,
            dateProvider: { Date(timeIntervalSince1970: 0) },
            directoryProvider: { _ in tempDir }
        )

        let session = TrainingSession(
            datum: Date(timeIntervalSince1970: 0),
            meter: 1500,
            dauerSek: 1800,
            borgWert: 6
        )
        let competition = Competition(
            datum: Date(timeIntervalSince1970: 86_400),
            name: "Sommer", ort: "Hamburg", bahn: .lcm50
        )
        competition.results.append(RaceResult(lage: .freistil, distanz: 100, zeitSek: 60))

        let url = try AutoBackupService.performBackup(
            sessions: [session],
            competitions: [competition],
            format: .zipBundle,
            configuration: config
        )

        let fileNames = try ZipArchive.fileNames(at: url)
        XCTAssertEqual(Set(fileNames), ["training.csv", "wettkaempfe.csv", "export.json"])
    }
}
