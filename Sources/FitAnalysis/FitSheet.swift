//
//  FitSheet.swift
//  FitAnalysis
//

/// Everything a full fit page shows: what is fitted, what it spends, and every stat in raw form.
///
/// Unlike `FitSummary`, tank figures are raw: hit points, repair rates and resonances by layer, so the
/// page can read them as raw or effective against any damage pattern without recalculating the fit.
public struct FitSheet: Sendable, Codable, Equatable {
    /// Fit name from the source text, if any.
    public var name: String?
    public var ship: Item
    public var shipGroupName: String
    /// Every module in rack order (`Slot.allCases`), by socket within a rack.
    public var modules: [Module]
    /// Drone stacks and fighter squadrons.
    public var drones: [Drone]
    /// Implants and boosters, each by slot.
    public var implants: [Item]
    public var boosters: [Item]
    public var resources: Resources
    public var hitPoints: FitSummary.Layers
    /// Damage multipliers per layer and damage type, `1 - resistance`.
    public var resonance: Resonance
    /// Raw repair rates, HP/s: every repairer cycling, and what the capacitor keeps running.
    public var tank: FitSummary.Tank
    public var damage: Damage
    public var capacitor: Capacitor
    public var navigation: Navigation
    public var targeting: Targeting
    /// Cargo hold, m³.
    public var cargoCapacity: Double
    /// Service module fuel; `nil` unless the hull is a structure.
    public var fuel: Fuel?
    /// The fit as calculated, in EFT.
    public var eft: String
    /// The same fit as a DNA string, the form the game's chat links carry.
    public var dna: String

    public init(name: String?,
                ship: Item,
                shipGroupName: String,
                modules: [Module],
                drones: [Drone],
                implants: [Item],
                boosters: [Item],
                resources: Resources,
                hitPoints: FitSummary.Layers,
                resonance: Resonance,
                tank: FitSummary.Tank,
                damage: Damage,
                capacitor: Capacitor,
                navigation: Navigation,
                targeting: Targeting,
                cargoCapacity: Double,
                fuel: Fuel?,
                eft: String,
                dna: String) {
        self.name = name
        self.ship = ship
        self.shipGroupName = shipGroupName
        self.modules = modules
        self.drones = drones
        self.implants = implants
        self.boosters = boosters
        self.resources = resources
        self.hitPoints = hitPoints
        self.resonance = resonance
        self.tank = tank
        self.damage = damage
        self.capacitor = capacitor
        self.navigation = navigation
        self.targeting = targeting
        self.cargoCapacity = cargoCapacity
        self.fuel = fuel
        self.eft = eft
        self.dna = dna
    }
}

extension FitSheet {

    public struct Item: Sendable, Codable, Equatable {
        public var typeID: UInt32
        public var name: String

        public init(typeID: UInt32, name: String) {
            self.typeID = typeID
            self.name = name
        }
    }

    public enum Slot: String, Sendable, Codable, CaseIterable {
        case hi, med, low, rig, subsystem, mode, service
    }

    public enum ModuleState: String, Sendable, Codable {
        case offline, online, active, overloaded
    }

    public struct Module: Sendable, Codable, Equatable {
        public var slot: Slot
        public var item: Item
        /// The requested state.
        public var state: ModuleState
        /// The state the engine applied; lower than `state` when the fit lacks resources.
        public var effectiveState: ModuleState
        public var charge: Charge?
        /// The mutaplasmid applied to the module; `item` is then the resulting abyssal type.
        public var mutaplasmid: Item?

        public init(slot: Slot, item: Item, state: ModuleState, effectiveState: ModuleState,
                    charge: Charge?, mutaplasmid: Item?) {
            self.slot = slot
            self.item = item
            self.state = state
            self.effectiveState = effectiveState
            self.charge = charge
            self.mutaplasmid = mutaplasmid
        }
    }

    public struct Charge: Sendable, Codable, Equatable {
        public var item: Item
        /// Charges in a full load: module capacity over charge volume, rounded down, at least one.
        public var count: Int

        public init(item: Item, count: Int) {
            self.item = item
            self.count = count
        }
    }

    public enum Squadron: String, Sendable, Codable, CaseIterable {
        case heavy, light, support, standupHeavy, standupLight, standupSupport
    }

    public struct Drone: Sendable, Codable, Equatable {
        public var item: Item
        public var count: Int
        /// In space rather than in the bay.
        public var isActive: Bool
        /// `nil` for an ordinary drone stack.
        public var squadron: Squadron?

        public init(item: Item, count: Int, isActive: Bool, squadron: Squadron?) {
            self.item = item
            self.count = count
            self.isActive = isActive
            self.squadron = squadron
        }
    }

    /// A count against a ceiling: slots, hardpoints, drones in space.
    public struct Count: Sendable, Codable, Equatable {
        public var used: Int
        public var total: Int

        public init(used: Int, total: Int) {
            self.used = used
            self.total = total
        }
    }

    public struct Resources: Sendable, Codable, Equatable {
        public var cpu: FitSummary.Usage
        public var powerGrid: FitSummary.Usage
        public var calibration: FitSummary.Usage
        /// Ordinary drones only; fighters use `fighterHangar`.
        public var droneBay: FitSummary.Usage
        public var droneBandwidth: FitSummary.Usage
        /// Ordinary drones in space; the engine's own count includes fighters.
        public var dronesInSpace: Count
        public var fighterHangar: FitSummary.Usage
        /// Launched squadrons against the hull's tubes.
        public var fighterTubes: Count
        /// Squadrons of each type against that type's slots; only the types the hull has slots or fighters for.
        public var squadrons: [Squadron: Count]
        /// Every rack the hull has or that holds a module anyway.
        public var slots: [Slot: Count]
        public var turrets: Count
        public var launchers: Count

        public init(cpu: FitSummary.Usage,
                    powerGrid: FitSummary.Usage,
                    calibration: FitSummary.Usage,
                    droneBay: FitSummary.Usage,
                    droneBandwidth: FitSummary.Usage,
                    dronesInSpace: Count,
                    fighterHangar: FitSummary.Usage,
                    fighterTubes: Count,
                    squadrons: [Squadron: Count],
                    slots: [Slot: Count],
                    turrets: Count,
                    launchers: Count) {
            self.cpu = cpu
            self.powerGrid = powerGrid
            self.calibration = calibration
            self.droneBay = droneBay
            self.droneBandwidth = droneBandwidth
            self.dronesInSpace = dronesInSpace
            self.fighterHangar = fighterHangar
            self.fighterTubes = fighterTubes
            self.squadrons = squadrons
            self.slots = slots
            self.turrets = turrets
            self.launchers = launchers
        }
    }

    public struct Resonance: Sendable, Codable, Equatable {
        public var shield: FitSummary.DamageProfile
        public var armor: FitSummary.DamageProfile
        public var hull: FitSummary.DamageProfile

        public init(shield: FitSummary.DamageProfile, armor: FitSummary.DamageProfile, hull: FitSummary.DamageProfile) {
            self.shield = shield
            self.armor = armor
            self.hull = hull
        }
    }

    /// Raw damage with no application penalties; the five sources sum to `dps`.
    public struct Damage: Sendable, Codable, Equatable {
        public var dps: FitSummary.DamageProfile
        public var volley: FitSummary.DamageProfile
        public var turrets: FitSummary.DamageProfile
        public var launchers: FitSummary.DamageProfile
        public var drones: FitSummary.DamageProfile
        public var fighters: FitSummary.DamageProfile
        public var otherModules: FitSummary.DamageProfile

        public init(dps: FitSummary.DamageProfile,
                    volley: FitSummary.DamageProfile,
                    turrets: FitSummary.DamageProfile,
                    launchers: FitSummary.DamageProfile,
                    drones: FitSummary.DamageProfile,
                    fighters: FitSummary.DamageProfile,
                    otherModules: FitSummary.DamageProfile) {
            self.dps = dps
            self.volley = volley
            self.turrets = turrets
            self.launchers = launchers
            self.drones = drones
            self.fighters = fighters
            self.otherModules = otherModules
        }
    }

    public struct Capacitor: Sendable, Codable, Equatable {
        public var capacity: Double
        public var rechargeTime: Double
        /// Net recharge minus drain at the stable level or on average, GJ/s.
        public var delta: Double
        /// Stable charge level, 0…1; `nil` if the capacitor runs dry.
        public var stableLevel: Double?
        /// Time until the capacitor runs dry; `nil` if it is stable.
        public var lastsFor: Double?

        public init(capacity: Double, rechargeTime: Double, delta: Double, stableLevel: Double?, lastsFor: Double?) {
            self.capacity = capacity
            self.rechargeTime = rechargeTime
            self.delta = delta
            self.stableLevel = stableLevel
            self.lastsFor = lastsFor
        }
    }

    public struct Navigation: Sendable, Codable, Equatable {
        public var maxVelocity: Double
        public var alignTime: Double
        public var signatureRadius: Double
        /// Kilograms.
        public var mass: Double
        /// AU/s.
        public var warpSpeed: Double
        /// AU on a full capacitor; 0 when the hull cannot warp.
        public var maxWarpDistance: Double

        public init(maxVelocity: Double, alignTime: Double, signatureRadius: Double, mass: Double,
                    warpSpeed: Double, maxWarpDistance: Double) {
            self.maxVelocity = maxVelocity
            self.alignTime = alignTime
            self.signatureRadius = signatureRadius
            self.mass = mass
            self.warpSpeed = warpSpeed
            self.maxWarpDistance = maxWarpDistance
        }
    }

    public enum SensorType: String, Sendable, Codable {
        case radar, ladar, magnetometric, gravimetric
    }

    public struct Targeting: Sendable, Codable, Equatable {
        public var maxTargetRange: Double
        public var scanResolution: Double
        public var maxLockedTargets: Int
        /// Strength of the dominant sensor.
        public var sensorStrength: Double
        public var sensorType: SensorType?

        public init(maxTargetRange: Double, scanResolution: Double, maxLockedTargets: Int,
                    sensorStrength: Double, sensorType: SensorType?) {
            self.maxTargetRange = maxTargetRange
            self.scanResolution = scanResolution
            self.maxLockedTargets = maxLockedTargets
            self.sensorStrength = sensorStrength
            self.sensorType = sensorType
        }
    }

    /// Fuel blocks an Upwell structure burns for its online service modules.
    public struct Fuel: Sendable, Codable, Equatable {
        public struct Service: Sendable, Codable, Equatable {
            public var item: Item
            public var perHour: Double
            public var toOnline: Double

            public init(item: Item, perHour: Double, toOnline: Double) {
                self.item = item
                self.perHour = perHour
                self.toOnline = toOnline
            }
        }

        public var services: [Service]
        public var perHour: Double
        public var toOnline: Double

        public init(services: [Service], perHour: Double, toOnline: Double) {
            self.services = services
            self.perHour = perHour
            self.toOnline = toOnline
        }
    }
}

extension FitSheet.Slot: CodingKeyRepresentable {}
extension FitSheet.Squadron: CodingKeyRepresentable {}
