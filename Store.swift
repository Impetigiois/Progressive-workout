import Foundation
import SwiftUI

struct ExWeek {
    var e1: Double
    var reps: Int
    var bestW: Double
    var bestR: Int
    var bestRir: Int?
    var vol: Double
    var sets: Int
}

struct WeekAgg {
    var vol = 0.0
    var sets = 0
    var rir: Double?
    var hit: Double?
    var hitN = 0
    var hn = 0
}

@MainActor
final class Store: ObservableObject {
    static let weeks = 7

    @Published var state: AppState { didSet { save() } }
    @Published var toast: String?
    /// Bumped whenever logged data is replaced wholesale, so set rows reload their text fields.
    @Published var epoch = 0

    private let fileURL: URL
    private var toastTask: Task<Void, Never>?

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("overload-log.json")
        fileURL = url
        var s = AppState()
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(AppState.self, from: data) {
            s = decoded
        }
        state = s
        normalize()
    }

    // MARK: persistence

    private func save() {
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private func normalize() {
        var s = state
        while s.rir.count < Store.weeks { s.rir.append(2) }
        s.week = min(Store.weeks, max(1, s.week))
        if s.days.isEmpty { s.days = AppState().days }
        if s.dayID == nil || !s.days.contains(where: { $0.id == s.dayID }) {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "EEE"
            let today = f.string(from: Date())
            s.dayID = (s.days.first { $0.dow == today } ?? s.days[0]).id
        }
        state = s
    }

    func backupJSON() -> String {
        var s = state
        s.timerKey = nil
        s.timerStart = nil
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        guard let data = try? enc.encode(s) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    func restore(from text: String) -> Bool {
        guard let data = text.data(using: .utf8),
              let s = try? JSONDecoder().decode(AppState.self, from: data),
              !s.days.isEmpty else { return false }
        state = s
        normalize()
        epoch += 1
        return true
    }

    func resetAll() {
        state = AppState()
        normalize()
        epoch += 1
    }

    func showToast(_ message: String) {
        toast = message
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            if !Task.isCancelled { toast = nil }
        }
    }

    // MARK: lookups

    func key(_ w: Int, _ id: UUID) -> String { "\(w)|\(id.uuidString)" }

    var currentDay: TrainingDay? {
        state.days.first { $0.id == state.dayID } ?? state.days.first
    }

    var allExercises: [Exercise] { state.days.flatMap { $0.exercises } + state.archived }

    func findExercise(_ id: UUID) -> Exercise? { allExercises.first { $0.id == id } }

    func isDeload(_ w: Int) -> Bool { state.rir.indices.contains(w - 1) && state.rir[w - 1] < 0 }
    func weekRir(_ w: Int) -> Int { state.rir.indices.contains(w - 1) ? max(0, state.rir[w - 1]) : 2 }
    func targetRir(_ e: Exercise, _ w: Int) -> Int { isDeload(w) ? 4 : max(e.rirFloor, weekRir(w)) }
    func nSets(_ e: Exercise, _ w: Int) -> Int { isDeload(w) ? max(2, e.sets - 1) : e.sets }
    func unit(_ e: Exercise) -> String { e.unit.isEmpty ? state.unit : e.unit }

    func setLogs(_ w: Int, _ e: Exercise) -> [SetLog] { state.logs[key(w, e.id)] ?? [] }
    func doneCount(_ w: Int, _ e: Exercise) -> Int { setLogs(w, e).filter { $0.done }.count }

    func dayCounts(_ w: Int, _ d: TrainingDay) -> (planned: Int, done: Int) {
        var pl = 0, dn = 0
        for e in d.exercises {
            let n = nSets(e, w)
            pl += n
            dn += min(doneCount(w, e), n)
        }
        return (pl, dn)
    }

    func weekFraction(_ w: Int) -> Double {
        var pl = 0, dn = 0
        for d in state.days {
            let c = dayCounts(w, d)
            pl += c.planned
            dn += c.done
        }
        return pl == 0 ? 0 : Double(dn) / Double(pl)
    }

    // MARK: logging

    func setLog(week: Int, exID: UUID, index: Int, _ change: (inout SetLog) -> Void) {
        let k = key(week, exID)
        var arr = state.logs[k] ?? []
        while arr.count <= index { arr.append(SetLog()) }
        change(&arr[index])
        state.logs[k] = arr
    }

    func startTimer(day: TrainingDay) {
        state.timerKey = key(state.week, day.id)
        state.timerStart = Date()
    }

    func finishSession(day: TrainingDay) {
        let k = key(state.week, day.id)
        var mins: Int?
        if state.timerKey == k, let start = state.timerStart {
            mins = Int((Date().timeIntervalSince(start) / 60).rounded())
            state.timerKey = nil
            state.timerStart = nil
        }
        state.done[k] = SessionDone(mins: mins, ts: Date())
        showToast(mins.map { "Session saved · \($0) min" } ?? "Session saved")
    }

    func reopenSession(day: TrainingDay) {
        state.done[key(state.week, day.id)] = nil
    }

    func swapExercise(_ id: UUID, to newName: String) {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { showToast("Type an exercise name first"); return }
        for di in state.days.indices {
            guard let ei = state.days[di].exercises.firstIndex(where: { $0.id == id }) else { continue }
            let old = state.days[di].exercises[ei]
            var new = old
            new.id = UUID()
            new.name = name
            new.startWeight = old.bw ? 0 : nil
            new.supported = true
            new.swap = ""
            state.days[di].exercises[ei] = new
            state.archived.append(old)
            state.flags.append(FlagEntry(ts: Date(), week: state.week, from: old.name, to: name))
            showToast("Swapped to \(name). Enter a comfortable starting weight.")
            return
        }
    }

    func addExercise(dayID: UUID) {
        guard let di = state.days.firstIndex(where: { $0.id == dayID }) else { return }
        var e = Exercise(name: "New exercise")
        e.sets = 2
        state.days[di].exercises.append(e)
    }

    func removeExercises(dayID: UUID, at offsets: IndexSet) {
        guard let di = state.days.firstIndex(where: { $0.id == dayID }) else { return }
        for i in offsets.sorted(by: >) {
            let old = state.days[di].exercises.remove(at: i)
            let hasLogs = state.logs.keys.contains { $0.hasSuffix("|" + old.id.uuidString) }
            if hasLogs { state.archived.append(old) }
        }
    }

    func addDay() {
        state.days.append(TrainingDay(name: "Day \(state.days.count + 1)"))
    }

    func removeDay(_ id: UUID) {
        guard state.days.count > 1 else { showToast("Keep at least one day"); return }
        state.days.removeAll { $0.id == id }
        if state.dayID == id { state.dayID = state.days.first?.id }
    }

    // MARK: progression engine

    func roundW(_ v: Double, _ e: Exercise) -> Double {
        let step = max(0.5, (e.inc > 0 ? e.inc : 5) / 2)
        return ((v / step).rounded() * step * 100).rounded() / 100
    }

    func lastPrior(_ e: Exercise, _ w: Int) -> (week: Int, sets: [SetLog?])? {
        guard w > 1 else { return nil }
        for k in stride(from: w - 1, through: 1, by: -1) {
            if isDeload(k) { continue }
            let dn: [SetLog?] = setLogs(k, e).map { $0.done ? $0 : nil }
            if dn.contains(where: { $0 != nil }) { return (k, dn) }
        }
        return nil
    }

    private func pick(_ dn: [SetLog?], _ i: Int) -> SetLog? {
        var j = min(i, dn.count - 1)
        while j >= 0 {
            if let s = dn[j] { return s }
            j -= 1
        }
        return dn.compactMap { $0 }.first
    }

    /// +1 rep per session, a weight step once the top of the range is reached,
    /// repeat the target if it was missed, and -10% on the deload week.
    func targets(_ e: Exercise, _ w: Int) -> [Target] {
        let dl = isDeload(w)
        let prev = lastPrior(e, w)
        let rir: Int? = e.kind == .power ? nil : targetRir(e, w)
        var out: [Target] = []
        for i in 0..<nSets(e, w) {
            if let prev, let p = pick(prev.sets, i), let pw = p.w, let pr = p.r {
                if dl {
                    out.append(Target(w: roundW(pw * 0.9, e), r: pr, why: "Deload −10%", rir: rir))
                } else if let tr = p.tr, pr < tr {
                    out.append(Target(w: pw, r: tr, why: "Hold", rir: rir))
                } else if pr >= e.repHigh && !(e.inc > 0) {
                    out.append(Target(w: pw, r: e.repHigh, why: "Maintain", rir: rir))
                } else if pr >= e.repHigh {
                    out.append(Target(w: roundW(pw + e.inc, e), r: e.repLow, why: "+\(fmt(e.inc)) \(unit(e))", rir: rir))
                } else {
                    out.append(Target(w: pw, r: pr + 1, why: "+1 rep", rir: rir))
                }
            } else {
                out.append(Target(w: e.startWeight, r: e.repLow, why: "Baseline", rir: rir))
            }
        }
        return out
    }

    // MARK: stats

    /// Estimated 1RM for lifts. Power work uses load x reps, or plain reps for bodyweight drills.
    func score(_ s: SetLog, _ e: Exercise) -> Double {
        let w = s.w ?? 0
        let r = Double(s.r ?? 0)
        if e.kind == .power { return w > 0 ? w * (1 + r / 30) : r }
        return w * (1 + (r + Double(s.rir ?? 0)) / 30)
    }

    func exWeek(_ e: Exercise, _ w: Int) -> ExWeek? {
        let d = setLogs(w, e).filter { $0.done }
        guard let best = d.max(by: { score($0, e) < score($1, e) }) else { return nil }
        let vol = d.reduce(0.0) { $0 + ($1.w ?? 0) * Double($1.r ?? 0) }
        return ExWeek(e1: score(best, e), reps: d.reduce(0) { $0 + ($1.r ?? 0) },
                      bestW: best.w ?? 0, bestR: best.r ?? 0, bestRir: best.rir, vol: vol, sets: d.count)
    }

    func exSeries(_ e: Exercise) -> [ExWeek?] { (1...Store.weeks).map { exWeek(e, $0) } }

    func exChange(_ e: Exercise) -> Double? {
        var first: (Int, ExWeek)?
        var last: (Int, ExWeek)?
        for (i, s) in exSeries(e).enumerated() {
            guard let s else { continue }
            let w = i + 1
            if first == nil { first = (w, s) }
            if !isDeload(w) { last = (w, s) }
        }
        guard let f = first, let l = last, l.0 != f.0, f.1.e1 > 0 else { return nil }
        return l.1.e1 / f.1.e1 - 1
    }

    func weekAgg(_ w: Int) -> WeekAgg {
        var a = WeekAgg()
        var rs = 0, rn = 0
        for e in allExercises {
            for s in setLogs(w, e) where s.done {
                let sw = s.w ?? 0, sr = s.r ?? 0
                if e.kind != .power { a.vol += sw * Double(sr) }
                a.sets += 1
                if let r = s.rir { rs += r; rn += 1 }
                if let tr = s.tr {
                    a.hn += 1
                    if sr >= tr && sw >= (s.tw ?? 0) { a.hitN += 1 }
                }
            }
        }
        a.rir = rn > 0 ? Double(rs) / Double(rn) : nil
        a.hit = a.hn > 0 ? Double(a.hitN) / Double(a.hn) : nil
        return a
    }

    // MARK: sample data

    private func hash(_ s: String) -> Int {
        var h = 0
        for c in s.utf16 { h = (h * 31 + Int(c)) % 9973 }
        return h
    }

    func clearLogs() {
        if state.sample {
            for id in state.sampleStarts {
                for di in state.days.indices {
                    for ei in state.days[di].exercises.indices where state.days[di].exercises[ei].id == id {
                        state.days[di].exercises[ei].startWeight = nil
                    }
                }
            }
        }
        state.logs = [:]
        state.done = [:]
        state.flags = []
        state.timerKey = nil
        state.timerStart = nil
        state.sample = false
        state.sampleStarts = []
        state.week = 1
        epoch += 1
    }

    func loadSample() {
        clearLogs()
        for di in state.days.indices {
            for ei in state.days[di].exercises.indices {
                let e = state.days[di].exercises[ei]
                if e.startWeight == nil {
                    let base: Double = e.inc >= 10 ? 140 : (e.inc >= 5 ? 80 : 20)
                    state.days[di].exercises[ei].startWeight = base + Double(hash(e.name) % 4) * e.inc * 2
                    state.sampleStarts.append(e.id)
                }
            }
        }
        for w in 1...4 {
            for (di, d) in state.days.enumerated() {
                for e in d.exercises {
                    let tg = targets(e, w)
                    var arr: [SetLog] = []
                    for (i, t) in tg.enumerated() {
                        let miss = (hash(e.name) + w * 3 + i) % 9 == 0
                        var l = SetLog()
                        l.w = t.w
                        l.r = miss ? max(1, t.r - 1) : t.r
                        if let tr = t.rir { l.rir = miss ? tr + 1 : tr }
                        l.done = true
                        l.tw = t.w
                        l.tr = t.r
                        arr.append(l)
                    }
                    state.logs[key(w, e.id)] = arr
                }
                state.done[key(w, d.id)] = SessionDone(mins: 40 + (w + di) % 5, ts: Date())
            }
        }
        state.sample = true
        state.week = 5
        state.dayID = state.days.first?.id
        epoch += 1
    }
}
