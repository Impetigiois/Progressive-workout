import Foundation

enum ExerciseKind: String, Codable, CaseIterable, Identifiable {
    case lift, power
    var id: String { rawValue }
    var label: String { self == .lift ? "Strength (tracks RIR)" : "Power or plyo (no RIR)" }
}

struct Exercise: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var muscle = ""
    var sets = 3
    var repLow = 8
    var repHigh = 12
    var inc = 5.0
    var startWeight: Double?
    var supported = true
    var perSide = ""
    var rirFloor = 1
    var cadence = "3s down · 1s pause at stretch"
    var notes = ""
    var swap = ""
    var rest = ""
    var kind: ExerciseKind = .lift
    var unit = ""
    var bw = false
    var phase = ""
    var phaseTime = ""

    init(name: String) { self.name = name }
}

struct TrainingDay: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var dow = ""
    var power = false
    var tmin = 40
    var tmax = 45
    var exercises: [Exercise] = []

    init(name: String) { self.name = name }
}

struct SetLog: Codable, Hashable {
    var w: Double?
    var r: Int?
    var rir: Int?
    var done = false
    var tw: Double?
    var tr: Int?
}

struct SessionDone: Codable, Hashable {
    var mins: Int?
    var ts: Date
}

struct FlagEntry: Codable, Hashable, Identifiable {
    var id = UUID()
    var ts: Date
    var week: Int
    var from: String
    var to: String
}

/// Everything the app saves. RIR values per week: 0...4, or -1 for the deload week.
struct AppState: Codable {
    var unit = "lb"
    var rir: [Int] = [2, 2, 1, 1, 0, 0, -1]
    var week = 1
    var dayID: UUID?
    var days: [TrainingDay] = DefaultPlan.days()
    var logs: [String: [SetLog]] = [:]
    var done: [String: SessionDone] = [:]
    var archived: [Exercise] = []
    var flags: [FlagEntry] = []
    var timerKey: String?
    var timerStart: Date?
    var sample = false
    var sampleStarts: [UUID] = []
}

struct Target {
    var w: Double?
    var r: Int
    var why: String
    var rir: Int?
}

let weekdayChoices = ["", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

func fmt(_ v: Double) -> String {
    if v == v.rounded() { return String(Int(v)) }
    return String(format: "%g", v)
}

func fmtVol(_ v: Double) -> String {
    v >= 1000 ? String(format: "%.1fk", v / 1000) : String(Int(v.rounded()))
}

func pct(_ x: Double) -> String { String(format: "%+.1f%%", x * 100) }
