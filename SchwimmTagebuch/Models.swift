import Foundation
import SwiftData

@Model
final class AppUser {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var email: String
    var displayName: String
    var passwordHash: String
    @Relationship(deleteRule: .cascade) var sessions: [TrainingSession] = []
    @Relationship(deleteRule: .cascade) var competitions: [Competition] = []

    init(email: String, displayName: String, passwordHash: String) {
        self.id = UUID()
        self.email = email.lowercased()
        self.displayName = displayName
        self.passwordHash = passwordHash
    }
}

@Model
final class TrainingSession {
    @Attribute(.unique) var id: UUID
    var datum: Date
    var gesamtMeter: Int
    var gesamtDauerSek: Int
    var borgWert: Int = 5
    var intensitaet: Intensitaet?
    var notizen: String?
    var ort: Ort
    var gefuehl: String?
    @Relationship(deleteRule: .cascade) var sets: [WorkoutSet] = []
    @Relationship(deleteRule: .nullify, inverse: \AppUser.sessions) var owner: AppUser?

    init(
        datum: Date,
        meter: Int,
        dauerSek: Int,
        borgWert: Int,
        notizen: String? = nil,
        ort: Ort = .becken,
        gefuehl: String? = nil,
        intensitaet: Intensitaet? = nil,
        owner: AppUser? = nil
    ) {
        self.id = UUID()
        self.datum = datum
        self.gesamtMeter = meter
        self.gesamtDauerSek = dauerSek
        self.borgWert = Self.clampBorg(borgWert)
        self.notizen = notizen
        self.ort = ort
        self.gefuehl = gefuehl
        self.intensitaet = intensitaet
        self.owner = owner
    }

    private static func clampBorg(_ value: Int) -> Int {
        max(1, min(10, value))
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
    var equipment: [String] = []
    var technikSchwerpunkte: [String] = []
    var kommentar: String?
    @Relationship(deleteRule: .cascade, inverse: \SetLap.set) var laps: [SetLap] = []
    var session: TrainingSession?

    init(titel: String, wiederholungen: Int, distanzProWdh: Int, intervallSek: Int, equipment: [String] = [], technikSchwerpunkte: [String] = [], kommentar: String? = nil, session: TrainingSession? = nil) {
        self.titel = titel
        self.wiederholungen = wiederholungen
        self.distanzProWdh = distanzProWdh
        self.intervallSek = intervallSek
        self.equipment = equipment
        self.technikSchwerpunkte = technikSchwerpunkte
        self.kommentar = kommentar
        self.session = session
    }
}

enum TrainingEquipment: String, Codable, CaseIterable, Identifiable {
    case pullbuoy
    case paddles
    case fins
    case snorkel
    case kickboard
    case resistanceBand
    case parachute
    case tempoTrainer

    var id: String { rawValue }

    var titel: String {
        switch self {
        case .pullbuoy: return "Pullbuoy"
        case .paddles: return "Paddles"
        case .fins: return "Flossen"
        case .snorkel: return "Schnorchel"
        case .kickboard: return "Brett"
        case .resistanceBand: return "Band"
        case .parachute: return "Fallschirm"
        case .tempoTrainer: return "Tempo-Trainer"
        }
    }

    var systemImage: String {
        switch self {
        case .pullbuoy: return "figure.pool.swim"
        case .paddles: return "hand.raised"
        case .fins: return "sailboat"
        case .snorkel: return "waveform.path.ecg"
        case .kickboard: return "rectangle.portrait"
        case .resistanceBand: return "figure.strengthtraining.traditional"
        case .parachute: return "wind"
        case .tempoTrainer: return "metronome"
        }
    }
}

enum TechniqueFocus: String, Codable, CaseIterable, Identifiable {
    case breathing
    case kick
    case catchPhase
    case turns
    case starts
    case paceControl
    case coordination
    case openWaterSkills

    var id: String { rawValue }

    var titel: String {
        switch self {
        case .breathing: return "Atmung"
        case .kick: return "Beine"
        case .catchPhase: return "Zugphase"
        case .turns: return "Wenden"
        case .starts: return "Starts"
        case .paceControl: return "Pace"
        case .coordination: return "Koordination"
        case .openWaterSkills: return "Freiwasser"
        }
    }

    var beschreibung: String {
        switch self {
        case .breathing: return "Atemrhythmus, Bilateralität und Timing."
        case .kick: return "Kick-Frequenz, Druckphase und Position."
        case .catchPhase: return "Hoher Ellbogen, Druckrichtung und Abdruck."
        case .turns: return "Kopflage, Anschlag und Abstoß."
        case .starts: return "Blockstart, Flugphase und Eintauchwinkel."
        case .paceControl: return "Gleichmäßige Splits und Intervalltreue."
        case .coordination: return "Arm-/Beinabstimmung und Rhythmuswechsel."
        case .openWaterSkills: return "Orientierung, Sighting und Navigationswechsel."
        }
    }
}

@Model
final class SetLap {
    @Attribute(.unique) var id: UUID
    var index: Int
    var splitSek: Int
    var set: WorkoutSet?

    init(index: Int, splitSek: Int, set: WorkoutSet? = nil) {
        self.id = UUID()
        self.index = index
        self.splitSek = splitSek
        self.set = set
    }
}

@Model
final class Competition {
    var datum: Date
    var name: String
    var ort: String
    var bahn: Bahn
    @Relationship(deleteRule: .cascade) var results: [RaceResult] = []
    @Relationship(deleteRule: .nullify, inverse: \AppUser.competitions) var owner: AppUser?

    init(datum: Date, name: String, ort: String = "", bahn: Bahn = .scm25, owner: AppUser? = nil) {
        self.datum = datum
        self.name = name
        self.ort = ort
        self.bahn = bahn
        self.owner = owner
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
