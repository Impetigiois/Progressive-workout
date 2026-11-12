import Foundation

/// The starting program: Push (Mon), Legs (Tue), Pull (Wed), Plyometrics (Fri).
enum DefaultPlan {
    private static func lift(
        _ name: String, _ muscle: String, sets: Int, reps: ClosedRange<Int>, inc: Double,
        floor: Int = 1, notes: String, swap: String, perSide: String = "",
        supported: Bool = true, cadence: String? = nil
    ) -> Exercise {
        var e = Exercise(name: name)
        e.muscle = muscle
        e.sets = sets
        e.repLow = reps.lowerBound
        e.repHigh = reps.upperBound
        e.inc = inc
        e.rirFloor = floor
        e.notes = notes
        e.swap = swap
        e.perSide = perSide
        e.supported = supported
        if let cadence { e.cadence = cadence }
        return e
    }

    private static func power(
        _ name: String, _ muscle: String, phase: String, time: String, sets: Int,
        reps: ClosedRange<Int>, bw: Bool, inc: Double, rest: String, unit: String = "",
        perSide: String = "", supported: Bool = false, cadence: String, notes: String, swap: String
    ) -> Exercise {
        var e = Exercise(name: name)
        e.kind = .power
        e.muscle = muscle
        e.phase = phase
        e.phaseTime = time
        e.sets = sets
        e.repLow = reps.lowerBound
        e.repHigh = reps.upperBound
        e.bw = bw
        e.startWeight = bw ? 0 : nil
        e.inc = inc
        e.rest = rest
        e.unit = unit
        e.perSide = perSide
        e.supported = supported
        e.cadence = cadence
        e.notes = notes
        e.swap = swap
        e.rirFloor = 0
        return e
    }

    static func days() -> [TrainingDay] {
        var push = TrainingDay(name: "Push")
        push.dow = "Mon"
        push.exercises = [
            lift("Low Incline DB Press (30°)", "Chest (upper / clavicular)", sets: 3, reps: 10...14, inc: 5,
                 notes: "3s eccentric. Lower back neutral against the pad.", swap: "Machine Incline Press"),
            lift("Converging Cable Chest Press (or Machine Dip)", "Chest (sternal / costal)", sets: 3, reps: 12...15, inc: 5,
                 notes: "Chest-supported or cable setup. Peak contraction cross-body.", swap: "Seated Machine Chest Press"),
            lift("Cross-Body Cable Lateral Raise", "Side delts", sets: 3, reps: 15...20, inc: 2.5, floor: 0,
                 notes: "Set at hip height. Keep the scapular plane alignment.", swap: "Seated DB Lateral Raise"),
            lift("Incline Cable Overhead Extension (rope / dual handles)", "Triceps (long head)", sets: 3, reps: 12...15, inc: 2.5,
                 notes: "Bench at a slight incline, upper back braced to protect T10–T12.", swap: "Seated Machine Triceps Extension"),
            lift("Cross-Body Cable Triceps Pushdown", "Triceps (lateral / medial)", sets: 2, reps: 15...20, inc: 2.5, floor: 0,
                 notes: "High cable setup, arms crossing, zero spinal compression.", swap: "Machine Triceps Extension"),
        ]

        var legs = TrainingDay(name: "Legs")
        legs.dow = "Tue"
        legs.exercises = [
            lift("Seated Leg Curl", "Hamstrings (lengthened)", sets: 3, reps: 10...14, inc: 5,
                 notes: "Hips locked into the back pad, zero spinal load.", swap: "Lying Leg Curl"),
            lift("Chest-Supported 45° Hip Extension", "Glutes and hamstrings", sets: 3, reps: 12...15, inc: 5,
                 notes: "Pad sits below the ASIS. Avoid hyperextension at T10–T12.", swap: "Machine Glute Kickback"),
            lift("Heel-Elevated Smith Squat / Goblet Squat", "Quads", sets: 3, reps: 12...15, inc: 5,
                 notes: "Torso strictly vertical. Heels elevated to prevent forward lean.", swap: "Leg Press", supported: false),
            lift("Front-Foot Elevated Split Squat / Reverse Lunge", "Glutes and adductors", sets: 2, reps: 12...15, inc: 5,
                 notes: "Front foot elevated 2–4 in, hand-supported on the rack.", swap: "Single-Leg Leg Press", perSide: "leg"),
            lift("Leg Extension", "Quads (shortened)", sets: 3, reps: 15...20, inc: 5, floor: 0,
                 notes: "2s pause at lockout. Back flush against the seat.", swap: "Leg Press (feet low)",
                 cadence: "3s down · 2s squeeze at lockout"),
        ]

        var pull = TrainingDay(name: "Pull")
        pull.dow = "Wed"
        pull.exercises = [
            lift("Single-Arm Half-Kneeling Lat Pulldown", "Lats (iliac / thoracic)", sets: 3, reps: 12...15, inc: 5,
                 notes: "Elbow tight to hip. Unilateral fiber line, zero axial loading.", swap: "Single-Arm Seated Lat Pulldown", perSide: "side"),
            lift("Chest-Supported Neutral-Grip Machine Row", "Upper back / rhomboids", sets: 3, reps: 10...12, inc: 5,
                 notes: "Chest pad takes the load off the erectors. Full scapular stretch.", swap: "Seated Cable Row (chest pad)"),
            lift("Neutral-Grip Lat Pulldown", "Lats / mid-back", sets: 2, reps: 12...15, inc: 5,
                 notes: "Torso held still, no swinging. Pull to the clavicle.", swap: "Machine Pullover"),
            lift("Chest-Supported Incline DB Rear Delt Fly", "Rear delts", sets: 3, reps: 15...20, inc: 2.5, floor: 0,
                 notes: "30–45° bench, pinkies slightly out, zero back load.", swap: "Reverse Pec Deck"),
            lift("Incline Dumbbell Curl", "Biceps", sets: 3, reps: 10...14, inc: 2.5,
                 notes: "45–60° incline, back anchored flush, deep bicep stretch.", swap: "Preacher Curl"),
        ]

        let p1 = "Phase 1: Elastic Priming", t1 = "8–10 min"
        let p2 = "Phase 2: Triple Extension & Power", t2 = "15–18 min"
        let p3 = "Phase 3: Posterior Chain & Decompression", t3 = "8–10 min"
        var plyo = TrainingDay(name: "Plyometrics")
        plyo.dow = "Fri"
        plyo.power = true
        plyo.tmin = 31
        plyo.tmax = 38
        plyo.exercises = [
            power("Ankle Pogo Hops (double leg)", "Calves and Achilles (elastic)", phase: p1, time: t1, sets: 3, reps: 20...25,
                  bw: true, inc: 0, rest: "45s", cadence: "Quick, minimal ground contact",
                  notes: "Stiff ankles, dorsiflexed toes. Minimize ground contact and knee bend.", swap: "Seated Calf Raise (fast reps)"),
            power("Drop Split Squat Catches", "Quads and glutes (eccentric catch)", phase: p1, time: t1, sets: 2, reps: 6...8,
                  bw: true, inc: 0, rest: "45s", perSide: "side", cadence: "Drop fast, stick the landing",
                  notes: "Drop instantly from a tall stance into a split squat. Stick a parallel landing.", swap: "Hand-Supported Split Squat"),
            power("Skater Bounds with Stick", "Glutes and lateral hips", phase: p1, time: t1, sets: 2, reps: 6...8,
                  bw: true, inc: 0, rest: "60s", perSide: "side", cadence: "Bound, then hold 1 s",
                  notes: "Drive laterally off the outer edge. Stick the single-leg landing for 1 full second.", swap: "Lateral Band Walk"),
            power("Seated Box Jump", "Quads, glutes (explosive)", phase: p2, time: t2, sets: 3, reps: 4...5,
                  bw: false, inc: 2, rest: "90s", unit: "in", cadence: "Explode up, land soft",
                  notes: "Log box height in inches. Dead-stop start to remove the countermovement. Explode up, land soft.",
                  swap: "Leg Press Jump (light, machine)"),
            power("Hang Power Clean (very light)", "Hips, traps, full chain", phase: p2, time: t2, sets: 4, reps: 3...3,
                  bw: false, inc: 5, rest: "90–120s", cadence: "Explosive hip snap",
                  notes: "About 40–50% of your 1RM. Maximize the violent hip snap and rapid elbow turnover.",
                  swap: "Seated Medicine Ball Chest Pass"),
            power("Broad Jump to Throw (or BW jump)", "Glutes, hamstrings, quads", phase: p2, time: t2, sets: 3, reps: 4...4,
                  bw: true, inc: 0, rest: "60–90s", cadence: "Max distance, soft landing",
                  notes: "Max horizontal displacement. Land absorbing through the hips and glutes.",
                  swap: "Seated Medicine Ball Chest Throw"),
            power("Banded Reverse Hyperextension", "Glutes and hamstrings", phase: p3, time: t3, sets: 3, reps: 15...20,
                  bw: false, inc: 5, rest: "60s", supported: true, cadence: "Snap up, slow return",
                  notes: "Log band resistance in lb. Heavy band around the ankles. Peak glute squeeze. Allow lower-spine traction at the bottom.",
                  swap: "Chest-Supported 45° Hip Extension"),
            power("Hanging Knee / Leg Tucks", "Abs and hip flexors", phase: p3, time: t3, sets: 2, reps: 12...15,
                  bw: true, inc: 0, rest: "", cadence: "Controlled, no swing",
                  notes: "Hang long to decompress, curl the pelvis up, lower slowly.", swap: "Captain's Chair Knee Raise"),
        ]

        return [push, legs, pull, plyo]
    }
}
