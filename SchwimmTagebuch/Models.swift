import Foundation
import SwiftData

@Model
final class TrainingSession {
    @Attribute(.unique) var id: UUID
    var datum: Date
    var gesamtMeter: Int
    var gesamtDauerSek: Int
    var intensitaet: Intensitaet
    var notizen: String?
    var ort: Ort
    @Relationship(deleteRule: .cascade) var sets: [WorkoutSet] = []

    init(datum: Date, meter: Int, dauerSek: Int, intensitaet: Intensitaet, notizen: String? = nil, ort: Ort = .becken) {
        self.id = UUID()
        self.datum = datum
        self.gesamtMeter = meter
        self.gesamtDauerSek = dauerSek
        self.intensitaet = intensitaet
        self.notizen = notizen
        self.ort = ort
    }
}

enum Intensitaet: String, Codable, CaseIterable, Identifiable {
    case locker, aerob, schwelle, vo2, sprint, regenerativ
    var id: String { rawValue }
    var titel: String {
        switch self {
        case .locker: return "Locker"
        case .aerob: return "Aerob"
        case .schwelle: return "Schwelle"
        case .vo2: return "VO2max"
        case .sprint: return "Sprint"
        case .regenerativ: return "Regenerativ"
        }
    }
}

enum Ort: String, Codable, CaseIterable, Identifiable {
    case becken, freiwasser
    var id: String { rawValue }
    var titel: String { self == .becken ? "Becken" : "Freiwasser" }
}

@Model
final class WorkoutSet {
    var titel: String
    var wiederholungen: Int
    var distanzProWdh: Int
    var intervallSek: Int
    var equipment: [String]
    var kommentar: String?
    @Relationship(inverse: \SetLap.set, deleteRule: .cascade) var laps: [SetLap] = []
    var session: TrainingSession?

    init(titel: String, wiederholungen: Int, distanzProWdh: Int, intervallSek: Int, equipment: [String] = [], kommentar: String? = nil, session: TrainingSession? = nil) {
        self.titel = titel
        self.wiederholungen = wiederholungen
        self.distanzProWdh = distanzProWdh
        self.intervallSek = intervallSek
        self.equipment = equipment
        self.kommentar = kommentar
        self.session = session
    }
}

@Model
final class SetLap {
    var index: Int
    var splitSek: Int
    var set: WorkoutSet?

    init(index: Int, splitSek: Int, set: WorkoutSet? = nil) {
        self.index = index
        self.splitSek = splitSek
        self.set = set
    }
}

@Model
final class Competition {
    var datum: Date
    var name: String
    var ort: String?
    var bahn: Bahn
    @Relationship(deleteRule: .cascade) var results: [RaceResult] = []

    init(datum: Date, name: String, ort: String? = nil, bahn: Bahn = .scm25) {
        self.datum = datum
        self.name = name
        self.ort = ort
        self.bahn = bahn
    }
}

enum Bahn: String, Codable, CaseIterable, Identifiable {
    case scm25, lcm50, openWater
    var id: String { rawValue }
    var titel: String {
        switch self {
            case .scm25: return "25 m"
            case .lcm50: return "50 m"
            case .openWater: return "Freiwasser"
        }
    }
}

@Model
final class RaceResult {
    var lage: Lage
    var distanz: Int
    var zeitSek: Int
    var lauf: Int?
    var bahn: Int?
    var platz: Int?
    var istPB: Bool
    var competition: Competition?

    init(lage: Lage, distanz: Int, zeitSek: Int, istPB: Bool = false, competition: Competition? = nil) {
        self.lage = lage
        self.distanz = distanz
        self.zeitSek = zeitSek
        self.istPB = istPB
        self.competition = competition
    }
}

enum Lage: String, Codable, CaseIterable, Identifiable {
    case freistil, ruecken, brust, schmetterling, lagen
    var id: String { rawValue }
    var titel: String {
        switch self {
        case .freistil: return "Freistil"
        case .ruecken: return "Rücken"
        case .brust: return "Brust"
        case .schmetterling: return "Schmetterling"
        case .lagen: return "Lagen"
        }
    }
}
