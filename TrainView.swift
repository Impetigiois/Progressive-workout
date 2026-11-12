import SwiftUI
import UIKit

struct TrainView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    WeekStrip()
                    DayChips()
                    if let day = store.currentDay {
                        SessionCard(day: day)
                        let week = store.state.week
                        ForEach(Array(day.exercises.enumerated()), id: \.element.id) { idx, e in
                            if !e.phase.isEmpty && (idx == 0 || day.exercises[idx - 1].phase != e.phase) {
                                PhaseHeader(title: e.phase, time: e.phaseTime)
                            }
                            ExerciseCard(exercise: e, week: week)
                        }
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Overload Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { dismissKeyboard() }
                }
            }
        }
        // Keep the screen on while someone is mid-workout.
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}

// MARK: week + day pickers

struct WeekStrip: View {
    @EnvironmentObject var store: Store

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...Store.weeks, id: \.self) { w in
                let selected = w == store.state.week
                Button {
                    store.state.week = w
                } label: {
                    VStack(spacing: 2) {
                        Text("W\(w)").font(.subheadline.weight(.semibold))
                        Text(store.isDeload(w) ? "DL" : "\(store.weekRir(w)) RIR")
                            .font(.caption2.monospaced())
                            .opacity(0.8)
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .foregroundStyle(selected ? Color.white : Color.primary)
                    .background(selected ? Color.accentColor : Color(.secondarySystemGroupedBackground))
                    .overlay(alignment: .bottomLeading) {
                        GeometryReader { g in
                            Rectangle()
                                .fill(selected ? Color.white : Color.green)
                                .frame(width: g.size.width * store.weekFraction(w), height: 3)
                                .frame(maxHeight: .infinity, alignment: .bottom)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Week \(w), \(store.isDeload(w) ? "deload" : "\(store.weekRir(w)) reps in reserve")")
            }
        }
    }
}

struct DayChips: View {
    @EnvironmentObject var store: Store

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.state.days) { d in
                    let selected = d.id == store.state.dayID
                    let c = store.dayCounts(store.state.week, d)
                    let finished = store.state.done[store.key(store.state.week, d.id)] != nil
                    Button {
                        store.state.dayID = d.id
                    } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(d.name).font(.headline)
                            Text((d.dow.isEmpty ? "" : d.dow + " · ") + (finished ? "Done" : "\(c.done)/\(c.planned) sets"))
                                .font(.caption2.monospaced())
                                .opacity(0.75)
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 50)
                        .foregroundStyle(selected ? Color(.systemBackground) : Color.primary)
                        .background(selected ? Color.primary : Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct PhaseHeader: View {
    let title: String
    let time: String

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title.uppercased())
                    .font(.headline)
                Spacer()
                Text(time).font(.caption.monospaced()).foregroundStyle(.secondary)
            }
            Rectangle().fill(Color.primary).frame(height: 2)
        }
        .padding(.top, 8)
    }
}

// MARK: session card

struct SessionCard: View {
    @EnvironmentObject var store: Store
    let day: TrainingDay

    var body: some View {
        let w = store.state.week
        let dl = store.isDeload(w)
        let k = store.key(w, day.id)
        let finished = store.state.done[k]
        let c = store.dayCounts(w, day)
        let frac = c.planned == 0 ? 0 : Double(c.done) / Double(c.planned)

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("WEEK \(w) OF \(Store.weeks)").font(.caption.monospaced()).foregroundStyle(.secondary)
                    Text(day.name).font(.largeTitle.weight(.semibold))
                }
                Spacer()
                Tag(text: day.power ? (dl ? "Deload" : "Max intent") : (dl ? "Deload · 4 RIR" : "\(store.weekRir(w)) RIR"),
                    tint: dl ? .green : .accentColor)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if day.power {
                        Tag(text: "Max intent"); Tag(text: "Stick every landing")
                    } else {
                        Tag(text: "Tempo 3-1-0"); Tag(text: "3 s down · 1 s pause at stretch")
                    }
                    Tag(text: "Target \(day.tmin)–\(day.tmax) min")
                }
            }

            if dl {
                Text(day.power
                     ? "Deload week. Weights drop about 10% and 3-set lifts drop to 2. Keep the same reps and stay crisp."
                     : "Deload week. Weights drop about 10% and 3-set lifts drop to 2. Stop 4 reps short and keep the same tempo.")
                    .font(.footnote)
            }

            HStack(spacing: 10) {
                ProgressView(value: frac)
                Text("\(c.done)/\(c.planned) sets").font(.caption.monospaced())
            }

            HStack(spacing: 10) {
                if let finished {
                    Text("Finished" + (finished.mins.map { " in \($0) min" } ?? ""))
                        .font(.subheadline.monospaced())
                    Spacer()
                    Button("Reopen") { store.reopenSession(day: day) }
                        .buttonStyle(.bordered)
                } else if store.state.timerKey == k, let start = store.state.timerStart {
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        let secs = max(0, Int(ctx.date.timeIntervalSince(start)))
                        let mins = Double(secs) / 60
                        Text(String(format: "%02d:%02d", secs / 60, secs % 60))
                            .font(.title2.monospacedDigit().weight(.medium))
                            .foregroundStyle(mins > Double(day.tmax) ? Color.red : (mins >= Double(day.tmin) ? Color.green : Color.primary))
                    }
                    Spacer()
                    Button("Finish session") { store.finishSession(day: day) }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Start session timer") { store.startTimer(day: day) }
                        .buttonStyle(.borderedProminent)
                    Button("Mark finished") { store.finishSession(day: day) }
                        .buttonStyle(.bordered)
                }
            }
            .controlSize(.large)

            Text("**Back safety:** discomfort, tingling or pressure at T10–T12? Tap Back flag on that exercise and swap to a supported version right away.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: exercise card

struct ExerciseCard: View {
    @EnvironmentObject var store: Store
    let exercise: Exercise
    let week: Int
    @State private var showFlag = false
    @State private var custom = ""

    var body: some View {
        let e = exercise
        let tg = store.targets(e, week)
        let logs = store.setLogs(week, e)
        let prev = store.lastPrior(e, week)
        let t0 = tg.first
        let power = e.kind == .power
        let unit = store.unit(e)

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(e.name).font(.title3.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                    if !e.muscle.isEmpty {
                        Text(e.muscle).font(.footnote.weight(.medium)).foregroundStyle(Color.accentColor)
                    }
                    Text(metaLine(e, tg.count, power))
                        .font(.caption.monospaced()).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Button("Back flag") { withAnimation { showFlag.toggle() } }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if let t0 {
                        Tag(text: t0.why, tint: tagTint(t0.why))
                        Tag(text: targetText(t0, e, unit))
                    }
                    Tag(text: e.cadence)
                    if e.supported { Tag(text: "Supported") } else { Tag(text: "Not supported: watch your back", tint: .orange) }
                }
            }

            if !e.notes.isEmpty {
                Text(e.notes).font(.footnote).foregroundStyle(.secondary)
            }

            // header row
            HStack(spacing: 8) {
                Text("SET").frame(width: 26)
                Text(e.bw ? "LOAD" : unit.uppercased()).frame(maxWidth: .infinity)
                Text("REPS" + (e.perSide.isEmpty ? "" : "/" + e.perSide.uppercased())).frame(maxWidth: .infinity)
                if !power { Text("RIR").frame(width: 54) }
                Color.clear.frame(width: 44, height: 1)
            }
            .font(.caption2.monospaced())
            .foregroundStyle(.secondary)

            ForEach(Array(tg.enumerated()), id: \.offset) { i, t in
                SetRow(exercise: e, week: week, index: i, target: t,
                       existing: i < logs.count ? logs[i] : SetLog())
                    .id("\(store.epoch)-\(week)-\(i)")
            }

            if let prev {
                Text("Wk \(prev.week): " + prev.sets.compactMap { $0 }.map { setText($0, e) }.joined(separator: " · "))
                    .font(.caption.monospaced()).foregroundStyle(.secondary)
            } else {
                Text("First time logging this lift. Enter your working weight.")
                    .font(.caption.monospaced()).foregroundStyle(.secondary)
            }

            if showFlag { flagPanel }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var flagPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("**Stop this exercise now.** Switch to an externally supported version (chest-supported or seated).")
                .font(.subheadline)
            if !exercise.swap.isEmpty {
                Button(role: .destructive) {
                    store.swapExercise(exercise.id, to: exercise.swap)
                } label: {
                    Text("Swap to \(exercise.swap)").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            HStack {
                TextField("Or type another supported exercise", text: $custom)
                    .textFieldStyle(.roundedBorder)
                Button("Swap") { store.swapExercise(exercise.id, to: custom) }
                    .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }

    private func metaLine(_ e: Exercise, _ n: Int, _ power: Bool) -> String {
        var s = "\(n) sets · \(e.repLow)–\(e.repHigh) reps" + (e.perSide.isEmpty ? "" : "/" + e.perSide)
        if power {
            if !e.rest.isEmpty { s += " · rest " + e.rest }
        } else {
            s += " · \(store.targetRir(e, week)) RIR"
        }
        return s
    }

    private func targetText(_ t: Target, _ e: Exercise, _ unit: String) -> String {
        var load: String
        if e.bw {
            load = "Bodyweight"
        } else if let w = t.w {
            load = fmt(w) + " " + unit
        } else {
            load = "enter " + unit
        }
        return "Target " + load + " × " + String(t.r)
    }

    private func setText(_ s: SetLog, _ e: Exercise) -> String {
        if e.bw { return "\(s.r ?? 0) reps" }
        let u = (!e.unit.isEmpty && e.unit != store.state.unit) ? " " + e.unit : ""
        return fmt(s.w ?? 0) + u + "×\(s.r ?? 0)"
    }

    private func tagTint(_ why: String) -> Color {
        if why == "Hold" { return .orange }
        if why.hasPrefix("Deload") { return .green }
        if why == "Baseline" || why == "Maintain" { return .secondary }
        return .accentColor
    }
}

// MARK: one set

struct SetRow: View {
    @EnvironmentObject var store: Store
    let exercise: Exercise
    let week: Int
    let index: Int
    let target: Target

    @State private var wText: String
    @State private var rText: String
    @State private var rirText: String
    @State private var done: Bool

    init(exercise: Exercise, week: Int, index: Int, target: Target, existing: SetLog) {
        self.exercise = exercise
        self.week = week
        self.index = index
        self.target = target
        var wStart = ""
        if let w = existing.w, !(exercise.bw && w == 0) { wStart = fmt(w) }
        _wText = State(initialValue: wStart)
        _rText = State(initialValue: existing.r.map { String($0) } ?? "")
        _rirText = State(initialValue: existing.rir.map { String($0) } ?? "")
        _done = State(initialValue: existing.done)
    }

    private var power: Bool { exercise.kind == .power }

    private func number(_ s: String) -> Double? {
        Double(s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }

    var body: some View {
        HStack(spacing: 8) {
            Text("\(index + 1)")
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 26)

            field($wText, placeholder: exercise.bw ? "BW" : (target.w.map { fmt($0) } ?? "—"), pad: .decimalPad)
            field($rText, placeholder: "\(target.r)", pad: .numberPad)
            if !power {
                field($rirText, placeholder: target.rir.map { "\($0)" } ?? "", pad: .numberPad)
                    .frame(width: 54)
            }

            Button(action: toggle) {
                Image(systemName: "checkmark")
                    .font(.headline)
                    .frame(width: 44, height: 44)
                    .foregroundStyle(done ? Color.white : Color.secondary)
                    .background(done ? Color.green : Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(done ? "Set \(index + 1) logged" : "Log set \(index + 1)")
        }
        .onChange(of: wText) { commit() }
        .onChange(of: rText) { commit() }
        .onChange(of: rirText) { commit() }
    }

    private func field(_ text: Binding<String>, placeholder: String, pad: UIKeyboardType) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(pad)
            .multilineTextAlignment(.center)
            .font(.title3.monospacedDigit().weight(.medium))
            .frame(minHeight: 44)
            .background(done ? Color.green.opacity(0.18) : Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
    }

    /// Save what was typed. A logged set whose weight or reps were cleared becomes unlogged.
    private func commit() {
        store.setLog(week: week, exID: exercise.id, index: index) { l in
            l.w = number(wText) ?? (exercise.bw ? 0 : nil)
            l.r = Int(rText)
            l.rir = power ? nil : Int(rirText)
            if l.done && (l.w == nil || l.r == nil) { l.done = false }
            done = l.done
        }
    }

    private func toggle() {
        if done {
            store.setLog(week: week, exID: exercise.id, index: index) { $0.done = false }
            done = false
            return
        }
        // Blank fields fall back to the target, so a perfect set is one tap.
        guard let wt = number(wText) ?? target.w ?? (exercise.bw ? 0 : nil) else {
            store.showToast("Enter the weight first")
            return
        }
        let reps = Int(rText) ?? target.r
        let rir: Int? = power ? nil : (Int(rirText) ?? target.rir)
        store.setLog(week: week, exID: exercise.id, index: index) { l in
            l.w = wt
            l.r = reps
            l.rir = rir
            l.done = true
            l.tw = target.w
            l.tr = target.r
        }
        wText = (exercise.bw && wt == 0) ? "" : fmt(wt)
        rText = String(reps)
        if let rir { rirText = String(rir) }
        done = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
