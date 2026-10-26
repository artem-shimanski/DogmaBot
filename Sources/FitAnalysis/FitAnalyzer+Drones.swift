//
//  FitAnalyzer+Drones.swift
//  FitAnalysis
//

import DogmaKit

extension FitAnalyzer {

    /// A drone stack or fighter squadron as the launch plan sees it.
    struct LaunchCandidate: Sendable, Equatable {
        var id: DroneID
        var typeID: TypeID
        /// `nil` for an ordinary drone.
        var squadron: FitSheet.Squadron?
        var count: Int
        /// Raw DPS of one drone, or of the whole squadron for fighters.
        var dps: Double
        /// Bandwidth of one drone.
        var bandwidth: Double
        /// A mutated stack cannot be split: it goes out whole or stays in the bay.
        var isMutated: Bool
    }

    /// What the hull and the pilot let into space at once.
    struct LaunchLimits: Sendable, Equatable {
        var drones: Int
        var bandwidth: Double
        var fighterTubes: Int
        /// Launched squadrons of each type; a type the hull has no slots for launches none.
        var squadrons: [FitSheet.Squadron: Int]
    }

    /// EFT, DNA and in-game XML do not say which drones are in space, and the importers launch them all.
    /// This keeps in space only as many drones and fighters as the hull and the pilot allow, the strongest
    /// first and, among equals, in the order of the fit; a drone stack that fits only in part is split in
    /// two. Returns what was left in the bay, as warnings.
    func launchDrones(_ engine: DogmaEngine) async -> [String] {
        // Every stack in space first: an inactive drone reports no damage to rank it by.
        let hasDrones = await engine.edit { fit -> Bool in
            guard let pilotID = fit.pilots.allIDs.first(where: { _ in true }) else { return false }
            let hull = fit[pilotID.hull]
            var hasDrones = false
            hull.drones.forEach { drone in
                drone.isActive = true
                hasDrones = true
            }
            return hasDrones
        }
        guard hasDrones else { return [] }

        let (candidates, limits) = await engine.evaluate { stats -> ([LaunchCandidate], LaunchLimits) in
            guard let pilotID = stats.pilots.allIDs.first(where: { _ in true }) else {
                return ([], LaunchLimits(drones: 0, bandwidth: 0, fighterTubes: 0, squadrons: [:]))
            }
            let hull = stats[pilotID.hull]
            var candidates: [LaunchCandidate] = []
            hull.drones.forEach { drone in
                let squadron = FitSheet.Squadron(drone.squadron)
                let count = max(drone.count, 1)
                let dps = drone.dps()
                let total = dps.em + dps.thermal + dps.kinetic + dps.explosive
                candidates.append(LaunchCandidate(id: drone.id,
                                                  typeID: drone.typeID,
                                                  squadron: squadron,
                                                  count: count,
                                                  dps: squadron == nil ? total / Double(count) : total,
                                                  bandwidth: drone.attributes[.droneBandwidthUsed] ?? 0,
                                                  isMutated: drone.isMutated))
            }
            var squadrons: [FitSheet.Squadron: Int] = [:]
            for squadron in FitSheet.Squadron.allCases {
                squadrons[squadron] = Int(hull.attributes[squadron.slotsAttribute] ?? 0)
            }
            let limits = LaunchLimits(drones: hull.dronesInSpace.total,
                                      bandwidth: hull.droneBandwidth.total,
                                      fighterTubes: Int(hull.attributes[.fighterTubes] ?? 0),
                                      squadrons: squadrons)
            return (candidates, limits)
        }

        let plan = Self.launchPlan(candidates, limits: limits)
        await engine.edit { fit in
            guard let pilotID = fit.pilots.allIDs.first(where: { _ in true }) else { return }
            let hull = fit[pilotID.hull]
            for candidate in candidates {
                let launched = plan[candidate.id] ?? 0
                let drone = fit[candidate.id]
                drone.isActive = launched > 0
                guard launched > 0, launched < candidate.count else { continue }
                // The rest of a split stack goes back to the bay as a stack of its own.
                drone.count = UInt8(launched)
                _ = try? hull.drones.add(candidate.typeID, count: UInt8(candidate.count - launched))
            }
        }

        return candidates.compactMap { candidate in
            let docked = candidate.count - (plan[candidate.id] ?? 0)
            guard docked > 0 else { return nil }
            let place = candidate.squadron == nil ? "drone bay" : "fighter hangar"
            return "Left in the \(place): \(name(candidate.typeID)) x\(docked)"
        }
    }

    /// How many of each stack go to space: drones by DPS per drone, fighters by DPS per squadron, the fit's
    /// order breaking ties. Drones are bound by the drone count and bandwidth, fighters by tubes and by the
    /// slots of their type.
    static func launchPlan(_ candidates: [LaunchCandidate], limits: LaunchLimits) -> [DroneID: Int] {
        let ranked = candidates.enumerated()
            .sorted { $0.element.dps != $1.element.dps ? $0.element.dps > $1.element.dps : $0.offset < $1.offset }
            .map(\.element)

        var plan: [DroneID: Int] = [:]
        var drones = limits.drones
        var bandwidth = limits.bandwidth
        var tubes = limits.fighterTubes
        var squadrons = limits.squadrons
        for candidate in ranked {
            if let squadron = candidate.squadron {
                let slots = squadrons[squadron] ?? 0
                guard tubes > 0, slots > 0 else { continue }
                tubes -= 1
                squadrons[squadron] = slots - 1
                plan[candidate.id] = candidate.count
                continue
            }
            var launched = min(candidate.count, drones)
            if candidate.bandwidth > 0 {
                // A small tolerance: bandwidth figures are sums of floating-point attributes.
                launched = min(launched, Int((bandwidth / candidate.bandwidth + 1e-9).rounded(.down)))
            }
            if candidate.isMutated && launched < candidate.count { launched = 0 }
            guard launched > 0 else { continue }
            drones -= launched
            bandwidth -= Double(launched) * candidate.bandwidth
            plan[candidate.id] = launched
        }
        return plan
    }
}
