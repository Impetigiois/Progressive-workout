import SwiftUI
import Charts

struct LiftStat: Identifiable {
    let e: Exercise
    let series: [ExWeek?]
    let change: Double?
    var id: UUID { e.id }
}

struct ProgressTabView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        NavigationStack {
            ScrollView {
                let weeks = (1...Store.weeks).map { store.weekAgg($0) }
                if weeks.allSatisfy({ $0.sets == 0 }) {
                    emptyState
                } else {
                    content(weeks)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("Nothing logged yet").font(.title2.weight(.semibold))
            Text("Log sets on the Train tab and your strength trend, weekly volume and target hit rate show up here.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Preview with sample data") { store.loadSample() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .card()
        .padding(16)
    }

    @ViewBuilder
    private func content(_ weeks: [WeekAgg]) -> some View {
        let lifts: [LiftStat] = store.allExercises
            .map { LiftStat(e: $0, series: store.exSeries($0), change: store.exChange($0)) }
            .filter { $0.series.contains { $0 != nil } }
        let strength = lifts.filter { $0.change != nil && $0.e.kind != .power }
        let avg: Double? = strength.isEmpty ? nil : strength.reduce(0.0) { $0 + ($1.change ?? 0) } / Double(strength.count)

        let loggedWeeks = (1...Store.weeks).filter { weeks[$0 - 1].sets > 0 }
        let firstW = loggedWeeks.first
        let lastW = loggedWeeks.last { !store.isDeload($0) }
        let volDelta: Double? = {
            guard let f = firstW, let l = lastW, l != f, weeks[f - 1].vol > 0 else { return nil }
            return weeks[l - 1].vol / weeks[f - 1].vol - 1
        }()
        let hitN = weeks.reduce(0) { $0 + $1.hitN }
        let hn = weeks.reduce(0) { $0 + $1.hn }
        let finished = store.state.done.count
        let planned = store.state.days.count * Store.weeks

        VStack(spacing: 14) {
            if store.state.sample {
                HStack {
                    Text("Sample data is loaded so you can preview the stats.").font(.footnote)
                    Spacer()
                    Button("Clear") { store.clearLogs() }.buttonStyle(.bordered).controlSize(.small)
                }
                .padding(12)
                .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                StatTile(label: "STRENGTH", value: avg.map(pct) ?? "—",
                         note: avg == nil ? "Needs two logged weeks" : "Avg est. 1RM change, \(strength.count) lifts",
                         tint: tint(avg))
                StatTile(label: "VOLUME LOAD", value: volDelta.map(pct) ?? "—",
                         note: (volDelta == nil || firstW == nil || lastW == nil) ? "Needs two logged weeks" : "Week \(lastW ?? 0) vs Week \(firstW ?? 0)",
                         tint: tint(volDelta))
                StatTile(label: "SETS ON TARGET", value: hn > 0 ? "\(Int((Double(hitN) / Double(hn) * 100).rounded()))%" : "—",
                         note: "\(hitN) of \(hn) sets hit weight and reps", tint: .primary)
                StatTile(label: "SESSIONS", value: "\(finished)/\(planned)", note: "Marked finished", tint: .primary)
            }

            Text(insight(strength: strength, lifts: lifts, avg: avg))
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()

            volumeChart(weeks)
            liftList(lifts)
            weekTable(weeks)

            if !store.state.flags.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Back flags").font(.title3.weight(.semibold))
                    ForEach(store.state.flags) { f in
                        Text("Week \(f.week): \(f.from) → \(f.to)").font(.subheadline)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
            }
        }
        .padding(16)
    }

    private func tint(_ v: Double?) -> Color {
        guard let v else { return .primary }
        return v > 0 ? .green : (v < 0 ? .red : .primary)
    }

    private func insight(strength: [LiftStat], lifts: [LiftStat], avg: Double?) -> String {
        guard let avg else { return "Log a second week and each lift gets a trend line." }
        var msg = "Estimated strength is \(avg >= 0 ? "up" : "down") \(String(format: "%.1f", abs(avg * 100)))% on average since your first logged week."
        if let best = strength.max(by: { ($0.change ?? 0) < ($1.change ?? 0) }), let c = best.change, c > 0 {
            msg += " Biggest gain: \(best.e.name) (\(pct(c)))."
        }
        let stalled = strength.filter { ($0.change ?? 0) <= 0 }
        if !stalled.isEmpty {
            msg += " Not moving yet: " + stalled.prefix(3).map { $0.e.name }.joined(separator: ", ") + "."
        }
        let power = lifts.filter { $0.e.kind == .power && $0.change != nil }
        if !power.isEmpty {
            msg += " Power drills improving: \(power.filter { ($0.change ?? 0) > 0 }.count) of \(power.count)."
        }
        return msg
    }

    private func volumeChart(_ weeks: [WeekAgg]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weekly volume load").font(.title3.weight(.semibold))
            Chart {
                ForEach(Array(1...Store.weeks), id: \.self) { w in
                    BarMark(x: .value("Week", "W\(w)"), y: .value("Volume", weeks[w - 1].vol))
                        .foregroundStyle(store.isDeload(w) ? Color.gray : Color.accentColor)
                        .annotation(position: .top) {
                            if weeks[w - 1].vol > 0 {
                                Text(fmtVol(weeks[w - 1].vol)).font(.caption2.monospacedDigit())
                            }
                        }
                }
            }
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 190)
            Text("Weight × reps, all strength lifts, in \(store.state.unit). Gray bar is the deload week.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .card()
    }

    private func liftList(_ lifts: [LiftStat]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Lift by lift").font(.title3.weight(.semibold))
            Text("Est. 1RM trend (best set each week). Tap a lift for its weeks.")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(lifts) { l in
                DisclosureGroup {
                    liftTable(l)
                } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(l.e.name).font(.subheadline.weight(.medium))
                            if l.e.kind == .power {
                                Text("Power · " + (l.e.bw ? "reps" : "load × reps")).font(.caption2.monospaced()).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Spark(values: l.series.map { $0?.e1 })
                        Text(l.change.map(pct) ?? "—")
                            .font(.footnote.monospacedDigit().weight(.medium))
                            .foregroundStyle(tint(l.change))
                            .frame(width: 62, alignment: .trailing)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func liftTable(_ l: LiftStat) -> some View {
        let power = l.e.kind == .power
        return ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .trailing, horizontalSpacing: 14, verticalSpacing: 6) {
                GridRow {
                    Text("Wk"); Text("Best set")
                    if power { Text("Reps") } else { Text("Est. 1RM"); Text("Volume") }
                    Text("Sets")
                }
                .font(.caption2.monospaced()).foregroundStyle(.secondary)
                ForEach(Array(l.series.enumerated()), id: \.offset) { i, s in
                    if let s {
                        GridRow {
                            Text("W\(i + 1)" + (store.isDeload(i + 1) ? " DL" : ""))
                            Text(bestText(s, l.e))
                            if power { Text("\(s.reps)") } else { Text("\(Int(s.e1.rounded()))"); Text(fmtVol(s.vol)) }
                            Text("\(s.sets)")
                        }
                        .font(.footnote.monospacedDigit())
                    }
                }
            }
            .padding(.top, 6)
        }
    }

    private func bestText(_ s: ExWeek, _ e: Exercise) -> String {
        if e.bw { return "\(s.bestR) reps" }
        return fmt(s.bestW) + "×\(s.bestR)" + (s.bestRir.map { " @\($0)" } ?? "")
    }

    private func weekTable(_ weeks: [WeekAgg]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Week by week").font(.title3.weight(.semibold))
            ScrollView(.horizontal, showsIndicators: false) {
                Grid(alignment: .trailing, horizontalSpacing: 14, verticalSpacing: 6) {
                    GridRow {
                        Text("Wk"); Text("RIR goal"); Text("Avg RIR"); Text("Sets"); Text("Volume"); Text("On target")
                    }
                    .font(.caption2.monospaced()).foregroundStyle(.secondary)
                    ForEach(Array(1...Store.weeks), id: \.self) { w in
                        let a = weeks[w - 1]
                        GridRow {
                            Text("W\(w)")
                            Text(store.isDeload(w) ? "DL (4)" : "\(store.weekRir(w))")
                            Text(a.rir.map { String(format: "%.1f", $0) } ?? "—")
                            Text(a.sets > 0 ? "\(a.sets)" : "—")
                            Text(a.vol > 0 ? fmtVol(a.vol) : "—")
                            Text(a.hit.map { "\(Int(($0 * 100).rounded()))%" } ?? "—")
                        }
                        .font(.footnote.monospacedDigit())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

struct StatTile: View {
    let label: String
    let value: String
    let note: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption.monospaced()).foregroundStyle(.secondary)
            Text(value).font(.system(size: 34, weight: .semibold, design: .rounded)).foregroundStyle(tint)
                .minimumScaleFactor(0.6).lineLimit(1)
            Text(note).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

struct Spark: View {
    let values: [Double?]

    var body: some View {
        let pts: [(Int, Double)] = values.enumerated().compactMap { i, v in v.map { (i, $0) } }
        Chart {
            ForEach(pts, id: \.0) { p in
                LineMark(x: .value("Week", p.0), y: .value("Score", p.1))
                    .interpolationMethod(.monotone)
            }
            ForEach(pts.suffix(1), id: \.0) { p in
                PointMark(x: .value("Week", p.0), y: .value("Score", p.1))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartXScale(domain: 0...(Store.weeks - 1))
        .chartYScale(domain: .automatic(includesZero: false))
        .frame(width: 70, height: 26)
    }
}

extension View {
    func card() -> some View {
        self
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}
