import Foundation

struct TrainingSetExportData {
    let title: String
    let repetitions: Int
    let distancePerRep: Int
    let intervalSec: Int
    let equipment: [String]
    let technique: [String]
    let laps: [Int]
}

struct TrainingSessionExportData {
    let id: UUID
    let date: Date
    let totalMeters: Int
    let totalDurationSec: Int
    let borg: Int
    let location: Ort
    let feeling: String
    let notes: String
    let equipmentSummary: [String]
    let techniqueSummary: [String]
    let sets: [TrainingSetExportData]

    var totalMinutes: Int { totalDurationSec / 60 }
    var locationTitle: String { location.titel }

    func dateString(using formatter: DateFormatter) -> String {
        formatter.string(from: date)
    }

    var equipmentSummaryString: String { equipmentSummary.joined(separator: "; ") }
    var techniqueSummaryString: String { techniqueSummary.joined(separator: "; ") }
}

struct CompetitionExportData {
    let date: Date
    let name: String
    let venue: String
    let course: Bahn
    let results: [RaceResultExportData]

    var courseTitle: String { course.titel }

    func dateString(using formatter: DateFormatter) -> String {
        formatter.string(from: date)
    }
}

struct RaceResultExportData {
    let stroke: Lage
    let distance: Int
    let timeSec: Int
    let rank: Int?
    let isPersonalBest: Bool

    var strokeTitle: String { stroke.titel }
}

enum ExportDataFactory {
    static func sessions(_ sessions: [TrainingSession]) -> [TrainingSessionExportData] {
        sessions.map { session in
            let setExports: [TrainingSetExportData] = session.sets.map { set in
                TrainingSetExportData(
                    title: set.titel,
                    repetitions: set.wiederholungen,
                    distancePerRep: set.distanzProWdh,
                    intervalSec: set.intervallSek,
                    equipment: ExportValueFormatter.localizedEquipmentNames(from: set.equipment),
                    technique: ExportValueFormatter.localizedTechniqueNames(from: set.technikSchwerpunkte),
                    laps: set.laps.map { $0.splitSek }
                )
            }

            return TrainingSessionExportData(
                id: session.id,
                date: session.datum,
                totalMeters: session.gesamtMeter,
                totalDurationSec: session.gesamtDauerSek,
                borg: session.borgWert,
                location: session.ort,
                feeling: session.gefuehl ?? "",
                notes: session.notizen ?? "",
                equipmentSummary: ExportValueFormatter.aggregatedEquipment(from: session.sets),
                techniqueSummary: ExportValueFormatter.aggregatedTechnique(from: session.sets),
                sets: setExports
            )
        }
    }

    static func competitions(_ competitions: [Competition]) -> [CompetitionExportData] {
        competitions.map { competition in
            let resultExports: [RaceResultExportData] = competition.results.map { result in
                RaceResultExportData(
                    stroke: result.lage,
                    distance: result.distanz,
                    timeSec: result.zeitSek,
                    rank: result.platz,
                    isPersonalBest: result.istPB
                )
            }

            return CompetitionExportData(
                date: competition.datum,
                name: competition.name,
                venue: competition.ort,
                course: competition.bahn,
                results: resultExports
            )
        }
    }
}

enum ExportValueFormatter {
    static func localizedEquipmentNames(from rawValues: [String]) -> [String] {
        rawValues.map { TrainingEquipment(rawValue: $0)?.titel ?? $0 }
    }

    static func localizedTechniqueNames(from rawValues: [String]) -> [String] {
        rawValues.map { TechniqueFocus(rawValue: $0)?.titel ?? $0 }
    }

    static func aggregatedEquipment(from sets: [WorkoutSet]) -> [String] {
        aggregateUniqueValues(from: sets.flatMap { $0.equipment }, transform: localizedEquipmentNames)
    }

    static func aggregatedTechnique(from sets: [WorkoutSet]) -> [String] {
        aggregateUniqueValues(from: sets.flatMap { $0.technikSchwerpunkte }, transform: localizedTechniqueNames)
    }

    private static func aggregateUniqueValues(from values: [String], transform: ([String]) -> [String]) -> [String] {
        let transformed = transform(values)
        let unique = Set(transformed)
        return unique.sorted()
    }
}

enum CSVFormatter {
    static func escape(_ value: String) -> String {
        let needsQuoting = value.contains(",") || value.contains("\n") || value.contains("\"")
        guard needsQuoting else { return value }

        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}
