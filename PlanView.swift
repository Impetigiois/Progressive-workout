import SwiftUI

struct PlanView: View {
    @EnvironmentObject var store: Store
    @State private var restoreText = ""
    @State private var pending: DataAction?

    enum DataAction: String, Identifiable {
        case sample, clear, reset
        var id: String { rawValue }
        var title: String {
            switch self {
            case .sample: return "Replace your logged sets with sample data?"
            case .clear: return "Clear every logged set?"
            case .reset: return "Reset the whole app to the starting plan?"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                rulesSection
                cycleSection

                ForEach($store.state.days) { $day in
                    Section {
                        HStack {
                            TextField("Day name", text: $day.name)
                                .font(.headline)
                            Picker("Weekday", selection: $day.dow) {
                                ForEach(weekdayChoices, id: \.self) { d in
                                    Text(d.isEmpty ? "—" : d).tag(d)
                                }
                            }
                            .labelsHidden()
                        }
                        ForEach($day.exercises) { $ex in
                            NavigationLink {
                                ExerciseEditor(ex: $ex)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ex.name)
                                    Text("\(ex.sets) sets · \(ex.repLow)–\(ex.repHigh) reps")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete { offsets in store.removeExercises(dayID: day.id, at: offsets) }
                        Button("Add exercise") { store.addExercise(dayID: day.id) }
                        Button("Remove this day", role: .destructive) { store.removeDay(day.id) }
                    } header: {
                        Text(day.name)
                    }
                }

                Section {
                    Button("Add training day") { store.addDay() }
                }

                dataSection
            }
            .navigationTitle("Plan")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(pending?.title ?? "", isPresented: Binding(
                get: { pending != nil },
                set: { if !$0 { pending = nil } }
            ), titleVisibility: .visible) {
                Button("Continue", role: .destructive) {
                    switch pending {
                    case .sample: store.loadSample()
                    case .clear: store.clearLogs(); store.showToast("Logged sets cleared")
                    case .reset: store.resetAll(); store.showToast("App reset")
                    case .none: break
                    }
                    pending = nil
                }
                Button("Cancel", role: .cancel) { pending = nil }
            }
        }
    }

    private var rulesSection: some View {
        Section("How this cycle works") {
            rule("Progression, weeks 1–4",
                 "Start Week 1 at 2 RIR on every working set. Each session add 1 rep, or take a small weight step once you reach the top of the rep range. Keep the same cadence: 3-second lowering, 1-second pause at the stretch. Weeks 5–7 follow the RIR targets below. Lifts marked 0–1 RIR follow the weekly target down to 0. The rest stop at 1.")
            rule("Back safety",
                 "Any exercise that causes discomfort, tingling or axial pressure at T10–T12 gets swapped right away for an externally supported version, such as chest-supported or seated instead of standing or hip-hinge. Use Back flag on the exercise.")
            rule("Logistics",
                 "Enter weight, reps and RIR for each set, like the RP app. Keep 2–3 working sets per exercise so a session fits in 40–45 minutes.")
            rule("How targets are calculated",
                 "Each target comes from your last logged session of that lift. Hit the target and it goes up. Miss it and you repeat it.")
            rule("Friday power day",
                 "Plyometrics have no RIR. Stop a set when jump height or speed drops. Reps climb to the top of the range, then load or box height goes up. Bodyweight drills hold at the top of the range, so the goal there is crisp, quick contacts.")
        }
    }

    private func rule(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.headline)
            Text(body).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var cycleSection: some View {
        Section("Cycle settings") {
            ForEach(0..<Store.weeks, id: \.self) { i in
                Picker("Week \(i + 1) target", selection: $store.state.rir[i]) {
                    ForEach(0...4, id: \.self) { Text("\($0) RIR").tag($0) }
                    Text("Deload").tag(-1)
                }
            }
            Picker("Weight unit", selection: $store.state.unit) {
                Text("lb").tag("lb")
                Text("kg").tag("kg")
            }
            .pickerStyle(.segmented)
        }
    }

    private var dataSection: some View {
        Section {
            Text("Everything is saved on this iPhone. Share a backup now and then, or to move to another device.")
                .font(.footnote).foregroundStyle(.secondary)
            ShareLink(item: store.backupJSON(), subject: Text("Overload Log backup")) {
                Label("Share backup", systemImage: "square.and.arrow.up")
            }
            TextField("Paste a backup here to restore it", text: $restoreText, axis: .vertical)
                .lineLimit(1...4)
                .font(.footnote.monospaced())
            Button("Restore from pasted text") {
                if store.restore(from: restoreText) {
                    restoreText = ""
                    store.showToast("Backup restored")
                } else {
                    store.showToast("That text is not a valid backup")
                }
            }
            .disabled(restoreText.isEmpty)
            Button("Load sample data") { pending = .sample }
            Button("Clear logged sets", role: .destructive) { pending = .clear }
            Button("Reset app", role: .destructive) { pending = .reset }
        } header: {
            Text("Your data")
        }
    }
}

struct ExerciseEditor: View {
    @Binding var ex: Exercise

    var body: some View {
        Form {
            Section("Exercise") {
                TextField("Name", text: $ex.name)
                TextField("Target muscle", text: $ex.muscle)
                Picker("Type", selection: $ex.kind) {
                    ForEach(ExerciseKind.allCases) { Text($0.label).tag($0) }
                }
                Toggle("Bodyweight movement (no load to log)", isOn: $ex.bw)
                    .onChange(of: ex.bw) {
                        if ex.bw && ex.startWeight == nil { ex.startWeight = 0 }
                    }
                Toggle("Externally supported (pad, seat or back support)", isOn: $ex.supported)
            }

            Section("Prescription") {
                Stepper("Sets: \(ex.sets)", value: $ex.sets, in: 1...6)
                Stepper("Reps from: \(ex.repLow)", value: $ex.repLow, in: 1...60)
                    .onChange(of: ex.repLow) { if ex.repLow > ex.repHigh { ex.repHigh = ex.repLow } }
                Stepper("Reps to: \(ex.repHigh)", value: $ex.repHigh, in: 1...60)
                    .onChange(of: ex.repHigh) { if ex.repHigh < ex.repLow { ex.repLow = ex.repHigh } }
                Picker("Reps count", selection: $ex.perSide) {
                    Text("Total").tag("")
                    Text("Per leg").tag("leg")
                    Text("Per side").tag("side")
                }
                if ex.kind == .lift {
                    Picker("Lowest RIR", selection: $ex.rirFloor) {
                        Text("0").tag(0)
                        Text("1").tag(1)
                    }
                }
                HStack {
                    Text("Starting weight")
                    Spacer()
                    TextField("—", value: $ex.startWeight, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Text("Step when range is topped")
                    Spacer()
                    TextField("5", value: $ex.inc, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                TextField("Load unit (blank uses your default)", text: $ex.unit)
                TextField("Rest, for example 90s", text: $ex.rest)
            }

            Section("Execution") {
                TextField("Cadence", text: $ex.cadence, axis: .vertical)
                TextField("Execution and back notes", text: $ex.notes, axis: .vertical)
                TextField("Supported swap if your back flags it", text: $ex.swap, axis: .vertical)
            }

            Section("Grouping (optional)") {
                TextField("Phase heading", text: $ex.phase)
                TextField("Phase time", text: $ex.phaseTime)
            }
        }
        .navigationTitle(ex.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { dismissKeyboard() }
            }
        }
    }
}
