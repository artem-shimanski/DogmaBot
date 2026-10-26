//
//  FitAnalyzer+Sheet.swift
//  FitAnalysis
//

import DogmaKit
import DogmaText

extension FitAnalyzer {

    /// The first pilot's hull as a full sheet. The fit name, EFT and DNA are left for the caller to fill.
    func sheet(_ engine: DogmaEngine) async -> FitSheet? {
        let names = names
        let item = { @Sendable (typeID: TypeID) in
            FitSheet.Item(typeID: typeID.rawValue, name: names.name(of: typeID) ?? "#\(typeID.rawValue)")
        }
        return await engine.evaluate { stats in
            guard let pilotID = stats.pilots.allIDs.first(where: { _ in true }) else { return nil }
            let hull = stats[pilotID.hull]

            var modules: [FitSheet.Module] = []
            for slot in Entity.Module.Slot.allCases {
                var rack: [(socket: Int, module: FitSheet.Module)] = []
                hull.modules.forEach(in: slot) { module in
                    var charge: FitSheet.Charge?
                    if let loaded = module.charge {
                        // A full load, as the game fills a module.
                        let volume = loaded.attributes[.volume] ?? 0
                        let capacity = module.attributes[.capacity] ?? 0
                        let count = volume > 0 ? max(Int((capacity / volume).rounded(.down)), 1) : 1
                        charge = FitSheet.Charge(item: item(loaded.typeID), count: count)
                    }
                    let mutaplasmid = module.isMutated ? module.mutaplasmidTypeID.map(item) : nil
                    rack.append((module.socket, FitSheet.Module(slot: .init(slot),
                                                                item: item(module.typeID),
                                                                state: .init(module.state),
                                                                effectiveState: .init(module.effectiveState),
                                                                charge: charge,
                                                                mutaplasmid: mutaplasmid)))
                }
                // Entity ids are not allocated in socket order.
                modules += rack.sorted { $0.socket < $1.socket }.map(\.module)
            }

            // The drones-in-space count covers ordinary drones only; fighters take tubes when launched.
            var drones: [FitSheet.Drone] = []
            var dronesInSpace = 0
            var squadronsLaunched = 0
            var squadronCounts: [FitSheet.Squadron: Int] = [:]
            hull.drones.forEach { drone in
                let squadron = FitSheet.Squadron(drone.squadron)
                if let squadron {
                    squadronCounts[squadron, default: 0] += 1
                    if drone.isActive { squadronsLaunched += 1 }
                } else if drone.isActive {
                    dronesInSpace += drone.count
                }
                drones.append(FitSheet.Drone(item: item(drone.typeID),
                                             count: drone.count,
                                             isActive: drone.isActive,
                                             squadron: squadron))
            }

            let pilot = stats[pilotID]
            var implants: [(slot: UInt16, item: FitSheet.Item)] = []
            pilot.implants.forEach { implants.append(($0.slot, item($0.typeID))) }
            var boosters: [(slot: UInt16, item: FitSheet.Item)] = []
            pilot.boosters.forEach { boosters.append(($0.slot, item($0.typeID))) }

            var slots: [FitSheet.Slot: FitSheet.Count] = [:]
            for slot in Entity.Module.Slot.allCases {
                let capacity = hull.capacity(of: slot)
                if capacity.total > 0 || capacity.used > 0 {
                    slots[.init(slot)] = .init(capacity)
                }
            }
            var squadrons: [FitSheet.Squadron: FitSheet.Count] = [:]
            for squadron in FitSheet.Squadron.allCases {
                let total = Int(hull.attributes[squadron.slotsAttribute] ?? 0)
                let used = squadronCounts[squadron] ?? 0
                if total > 0 || used > 0 {
                    squadrons[squadron] = .init(used: used, total: total)
                }
            }

            let resources = FitSheet.Resources(
                cpu: .init(hull.cpu),
                powerGrid: .init(hull.powerGrid),
                calibration: .init(hull.calibration),
                droneBay: .init(hull.droneBay),
                droneBandwidth: .init(hull.droneBandwidth),
                dronesInSpace: .init(used: dronesInSpace, total: hull.dronesInSpace.total),
                fighterHangar: .init(hull.fighterBay),
                fighterTubes: .init(used: squadronsLaunched, total: Int(hull.attributes[.fighterTubes] ?? 0)),
                squadrons: squadrons,
                slots: slots,
                turrets: .init(hull.capacity(of: .turret)),
                launchers: .init(hull.capacity(of: .launcher)))

            let resonance = hull.resonance
            let capacitor = hull.capacitor()
            let navigation = hull.navigation
            let targeting = hull.targeting

            var fuel: FitSheet.Fuel?
            if hull.categoryID == .structure {
                var services: [(socket: Int, service: FitSheet.Fuel.Service)] = []
                hull.modules.forEach(in: .service) { module in
                    // Online or above burns fuel, as in the engine's totals.
                    guard module.effectiveState >= .online else { return }
                    services.append((module.socket, .init(item: item(module.typeID),
                                                          perHour: module.serviceFuelPerHour,
                                                          toOnline: module.serviceFuelToOnline)))
                }
                fuel = FitSheet.Fuel(services: services.sorted { $0.socket < $1.socket }.map(\.service),
                                     perHour: hull.fuelPerHour,
                                     toOnline: hull.fuelToOnline)
            }

            return FitSheet(
                name: nil,
                ship: item(hull.typeID),
                shipGroupName: names.name(of: hull.groupID) ?? "",
                modules: modules,
                drones: drones,
                implants: implants.sorted { $0.slot < $1.slot }.map(\.item),
                boosters: boosters.sorted { $0.slot < $1.slot }.map(\.item),
                resources: resources,
                hitPoints: .init(hull.hitPoints),
                resonance: .init(shield: .init(resonance.shield),
                                 armor: .init(resonance.armor),
                                 hull: .init(resonance.hull)),
                tank: .init(peak: .init(hull.tank()), sustained: .init(hull.sustainableTank(capacitor: capacitor))),
                damage: .init(dps: .init(hull.dps()),
                              volley: .init(hull.volleyDamage()),
                              turrets: .init(hull.dps(from: .turrets)),
                              launchers: .init(hull.dps(from: .launchers)),
                              drones: .init(hull.dps(from: .drones)),
                              fighters: .init(hull.dps(from: .fighters)),
                              otherModules: .init(hull.dps(from: .otherModules))),
                capacitor: .init(capacity: capacitor.capacity,
                                 rechargeTime: capacitor.rechargeTime,
                                 delta: capacitor.delta,
                                 stableLevel: capacitor.stableLevel,
                                 lastsFor: capacitor.isStable ? nil : capacitor.lastsFor),
                navigation: .init(maxVelocity: navigation.maxVelocity,
                                  alignTime: navigation.alignTime,
                                  signatureRadius: navigation.signatureRadius,
                                  mass: navigation.mass,
                                  warpSpeed: navigation.warpSpeed,
                                  maxWarpDistance: navigation.maxWarpDistance),
                targeting: .init(maxTargetRange: targeting.maxTargetRange,
                                 scanResolution: targeting.scanResolution,
                                 maxLockedTargets: targeting.maxLockedTargets,
                                 sensorStrength: targeting.ecmResistance,
                                 sensorType: targeting.sensorType.map(FitSheet.SensorType.init)),
                cargoCapacity: hull.attributes[.capacity] ?? 0,
                fuel: fuel,
                eft: "",
                dna: "")
        }
    }
}

// MARK: - Conversions from engine values

extension FitSheet.Slot {
    init(_ slot: Entity.Module.Slot) {
        switch slot {
        case .hi: self = .hi
        case .med: self = .med
        case .low: self = .low
        case .rig: self = .rig
        case .subsystem: self = .subsystem
        case .mode: self = .mode
        case .service: self = .service
        }
    }
}

extension FitSheet.ModuleState {
    init(_ state: Entity.Module.State) {
        switch state {
        case .offline: self = .offline
        case .online: self = .online
        case .active: self = .active
        case .overloaded: self = .overloaded
        }
    }
}

extension FitSheet.Squadron {
    /// `nil` for an ordinary drone.
    init?(_ squadron: Entity.Drone.Squadron) {
        switch squadron {
        case .none: return nil
        case .heavy: self = .heavy
        case .light: self = .light
        case .support: self = .support
        case .standupHeavy: self = .standupHeavy
        case .standupLight: self = .standupLight
        case .standupSupport: self = .standupSupport
        }
    }

    /// The hull attribute with the number of slots for this squadron type.
    var slotsAttribute: AttributeID {
        switch self {
        case .heavy: .fighterHeavySlots
        case .light: .fighterLightSlots
        case .support: .fighterSupportSlots
        case .standupHeavy: .fighterStandupHeavySlots
        case .standupLight: .fighterStandupLightSlots
        case .standupSupport: .fighterStandupSupportSlots
        }
    }
}

extension FitSheet.SensorType {
    init(_ type: DogmaKit.SensorType) {
        switch type {
        case .radar: self = .radar
        case .ladar: self = .ladar
        case .magnetometric: self = .magnetometric
        case .gravimetric: self = .gravimetric
        }
    }
}

extension FitSheet.Count {
    init(_ capacity: SlotCapacity) {
        self.init(used: capacity.used, total: capacity.total)
    }
}
