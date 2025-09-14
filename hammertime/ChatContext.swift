//
//  ChatContext.swift
//  hammertime
//

import Foundation
import SwiftData

enum ChatContextBuilder {
    static func buildMetricsContext(modelContext: ModelContext, spanWeeks: Int = 26) throws -> [String] {
        let showSeed = UserDefaults.standard.bool(forKey: "showSeedData")
        var fd = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\Workout.startedAt, order: .forward)])
        let all = try modelContext.fetch(fd).filter { showSeed || !$0.isSeed }
        guard let lastDate = all.last?.startedAt else { return [] }
        let block = makeCompactMetricsJSONBlock(all: all, lastDate: lastDate, spanWeeks: spanWeeks)
        return [block]
    }

    static func buildCurrentStateContext(workout: Workout, currentExercise: Exercise?, restEndAt: Date?, restTotalSeconds: Int, nextSetId: UUID?) -> String {
        var dict: [String: Any] = [:]
        dict["type"] = "CURRENT_STATE_JSON"
        dict["workout_id"] = workout.id.uuidString
        dict["workout_name"] = workout.name
        dict["started_at_iso"] = ISO8601DateFormatter().string(from: workout.startedAt)

        if let ex = currentExercise {
            dict["exercise_id"] = ex.id.uuidString
            dict["exercise_name"] = ex.name
            let sorted = ex.sets.sorted { $0.setNumber < $1.setNumber }
            if let nextId = nextSetId, let s = sorted.first(where: { $0.id == nextId }) ?? sorted.last {
                var setDict: [String: Any] = [:]
                setDict["set_number"] = s.setNumber
                if let w = s.weightKg { setDict["weight_kg"] = Int(round(w)) }
                if let r = s.reps { setDict["reps"] = r }
                setDict["is_logged"] = s.isLogged
                dict["active_set"] = setDict
            }
        }

        if let end = restEndAt, end > Date() {
            let remaining = max(0, Int(end.timeIntervalSinceNow))
            dict["rest"] = [
                "remaining_seconds": remaining,
                "total_seconds": restTotalSeconds
            ]
        }

        let json = (try? JSONSerialization.data(withJSONObject: dict, options: [.withoutEscapingSlashes]))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return json
    }

    private static func makeCompactMetricsJSONBlock(all workouts: [Workout], lastDate: Date, spanWeeks: Int) -> String {
        let cal = Calendar(identifier: .iso8601)
        let tz = TimeZone(secondsFromGMT: 0) ?? .gmt
        var calZ = cal
        calZ.timeZone = tz

        func weekStart(for date: Date) -> Date {
            let comps = calZ.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            return calZ.date(from: comps) ?? date
        }

        let endWeekStart = weekStart(for: lastDate)
        let startWeek = calZ.date(byAdding: .weekOfYear, value: -(spanWeeks - 1), to: endWeekStart) ?? endWeekStart

        func weekIndex(_ date: Date) -> Int? {
            let start = startWeek
            let startToDate = calZ.dateComponents([.weekOfYear], from: start, to: weekStart(for: date)).weekOfYear ?? 0
            if startToDate < 0 || startToDate >= spanWeeks { return nil }
            return startToDate
        }

        enum LiftKey: String, CaseIterable { case bench, squat, deadlift, ohp, row, pullup, rdl }
        func liftKey(for name: String) -> LiftKey? {
            let n = name.lowercased()
            if n.contains("bench") { return .bench }
            if n.contains("squat") { return .squat }
            if n == "deadlift" || n.contains("deadlift") && !n.contains("romanian") { return .deadlift }
            if n.contains("overhead press") || n == "ohp" { return .ohp }
            if n.contains("row") { return .row }
            if n.contains("pull-up") || n.contains("pullup") { return .pullup }
            if n.contains("romanian") { return .rdl }
            return nil
        }

        enum MG: String, CaseIterable { case quad, ham, pec, back, delt }
        func mgFor(exName: String) -> MG? {
            let n = exName.lowercased()
            if n.contains("squat") { return .quad }
            if n.contains("romanian") { return .ham }
            if n.contains("deadlift") { return .back }
            if n.contains("bench") { return .pec }
            if n.contains("overhead press") { return .delt }
            if n.contains("row") || n.contains("pull-up") || n.contains("pullup") { return .back }
            return nil
        }

        var sessionsPerWeek = Array(repeating: 0, count: spanWeeks)
        var mgVol: [MG: [Int]] = [:]
        for mg in MG.allCases { mgVol[mg] = Array(repeating: 0, count: spanWeeks) }
        struct LiftAgg { var freq = 0; var vol = Array(repeating: 0, count: 26); var e1 = Array(repeating: 0, count: 26); var top: [(Date, Int, Int)] = [] }
        var byLift: [LiftKey: LiftAgg] = [:]

        var easy = 0, med = 0, hard = 0
        struct PR { let lift: LiftKey; let date: Date; let w: Int; let r: Int; let e1: Double }
        var bestByLift: [LiftKey: PR] = [:]

        for w in workouts {
            guard let wi = weekIndex(w.startedAt) else { continue }
            sessionsPerWeek[wi] += 1
            for ex in w.exercises {
                let lift = liftKey(for: ex.name)
                let mg = mgFor(exName: ex.name)
                var bestE1ThisWeek: Double = 0
                var bestSetThisWeek: (w: Int, r: Int)?
                var volThisExWeek = 0
                for s in ex.sets {
                    if let rpe = s.rpe {
                        let rir = max(0, Int(10 - round(rpe)))
                        if rir >= 3 { easy += 1 } else if rir >= 1 { med += 1 } else { hard += 1 }
                    }
                    if let weight = s.weightKg, let reps = s.reps {
                        let wInt = Int(round(weight))
                        volThisExWeek += Int(round(weight * Double(reps)))
                        let e1 = weight * (1.0 + Double(reps) / 30.0)
                        if e1 > bestE1ThisWeek { bestE1ThisWeek = e1; bestSetThisWeek = (wInt, reps) }
                    }
                }
                if let mg, volThisExWeek > 0 { mgVol[mg]?[wi] += volThisExWeek }
                if let lift {
                    var agg = byLift[lift] ?? LiftAgg()
                    agg.freq += 1
                    agg.vol[wi] += volThisExWeek
                    let bestE1Rounded = Int(round(bestE1ThisWeek))
                    if bestE1Rounded > agg.e1[wi] { agg.e1[wi] = bestE1Rounded }
                    if let top = bestSetThisWeek { agg.top.append((w.startedAt, top.w, top.r)) }
                    byLift[lift] = agg
                    if bestE1ThisWeek > 0 {
                        let pr = PR(lift: lift, date: w.startedAt, w: bestSetThisWeek?.w ?? 0, r: bestSetThisWeek?.r ?? 0, e1: bestE1ThisWeek)
                        if let prev = bestByLift[lift] {
                            if pr.e1 > prev.e1 { bestByLift[lift] = pr }
                        } else { bestByLift[lift] = pr }
                    }
                }
            }
        }

        for (k, var agg) in byLift {
            agg.top.sort { $0.0 > $1.0 }
            if agg.top.count > 2 { agg.top = Array(agg.top.prefix(2)) }
            byLift[k] = agg
        }

        var root: [String: Any] = [
            "u": "local",
            "span_wks": spanWeeks,
            "consistency": [
                "wks_trained": sessionsPerWeek.filter { $0 > 0 }.count,
                "sessions": sessionsPerWeek
            ],
            "intensity": [
                "easy": easy,
                "med": med,
                "hard": hard
            ]
        ]

        var mgDict: [String: Any] = [:]
        for mg in MG.allCases { mgDict[mg.rawValue] = mgVol[mg] ?? Array(repeating: 0, count: spanWeeks) }
        root["mg_vol"] = mgDict

        let iso = ISO8601DateFormatter()
        let prsArr: [[String: Any]] = bestByLift.values.map { pr in
            ["lift": pr.lift.rawValue, "date": iso.string(from: pr.date), "w": pr.w, "r": pr.r]
        }
        root["prs"] = prsArr.sorted { ($0["date"] as? String ?? "") > ($1["date"] as? String ?? "") }

        let preferred: [LiftKey] = [.squat, .bench, .deadlift, .ohp, .row, .pullup]
        var liftsDict: [String: Any] = [:]
        for key in preferred {
            if let agg = byLift[key] {
                var topArr: [[String: Any]] = []
                for (d, w, r) in agg.top { topArr.append(["d": iso.string(from: d), "w": w, "r": r]) }
                liftsDict[key.rawValue] = [
                    "freq": agg.freq,
                    "vol": agg.vol,
                    "e1rm": agg.e1,
                    "top": topArr
                ]
            }
        }
        root["lifts"] = liftsDict

        let json = (try? JSONSerialization.data(withJSONObject: root, options: [.withoutEscapingSlashes]))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return "METRICS_JSON:\n" + json
    }
}


