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
            intensitaet: .aerob,
            notizen: "Langer Satz",
            ort: .becken
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
        XCTAssertEqual(trainingZeilen[1], "1970-01-01,2500,60,Aerob,Becken,Langer Satz")

        let competitionZeilen = competitionCSV.split(separator: "\n", omittingEmptySubsequences: false)
        XCTAssertEqual(competitionZeilen.count, 2)
        XCTAssertEqual(competitionZeilen[1], "1970-01-02,Stadtmeisterschaft,Berlin,25 m,Freistil,100,62,2,true")
    }

    func testJSONExportEnthaeltSetsUndErgebnisse() {
        let session = TrainingSession(
            datum: Date(timeIntervalSince1970: 0),
            meter: 3000,
            dauerSek: 4500,
            intensitaet: .schwelle,
            notizen: "Mit Technikanteil",
            ort: .freiwasser
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
}
